"""Tap localization engine.

The built-in MacBook microphone is exposed by macOS as a single beamformed
channel, so time-difference-of-arrival triangulation is not possible. Instead
each tap is classified by its acoustic fingerprint: distance changes loudness
and high-frequency damping, and every spot on the table excites a different mix
of resonant modes with a different direct-to-reverberant ratio. Those
differences are stable for a fixed laptop/table setup, so a small nearest
neighbour model trained on a handful of taps per zone can tell them apart.
"""

from __future__ import annotations

import json
import math
import queue
import threading
import time
from dataclasses import dataclass, field
from pathlib import Path

import numpy as np
import sounddevice as sd

SR = 48000
BLOCK = 256

PRE = int(0.010 * SR)          # samples kept from before the onset
POST = int(0.190 * SR)         # samples captured after the onset
WIN = PRE + POST

REFRACTORY = 0.25              # seconds to ignore after a detected tap
RING = int(0.05 * SR)          # pre-onset ring buffer

ZONES = ["TL", "TR", "BL", "BR"]
ZONE_LABELS = {
    "TL": "Sol Üst",
    "TR": "Sağ Üst",
    "BL": "Sol Alt",
    "BR": "Sağ Alt",
}


# --------------------------------------------------------------------------
# Feature extraction
# --------------------------------------------------------------------------

def _log_bands(x: np.ndarray, lo: float, hi: float, n: int) -> np.ndarray:
    """Mean-removed log magnitude in `n` geometrically spaced bands.

    Removing the mean discards absolute loudness, which mostly reflects how
    hard the user hit the table rather than where they hit it.
    """
    if len(x) < 32:
        return np.zeros(n)
    w = np.hanning(len(x))
    mag = np.abs(np.fft.rfft(x * w))
    freqs = np.fft.rfftfreq(len(x), 1.0 / SR)
    edges = np.geomspace(lo, hi, n + 1)
    out = np.empty(n)
    for i in range(n):
        m = (freqs >= edges[i]) & (freqs < edges[i + 1])
        out[i] = math.log(float(mag[m].mean()) + 1e-9) if m.any() else -20.0
    return out - out.mean()


def _centroid(x: np.ndarray) -> float:
    if len(x) < 32:
        return 0.0
    mag = np.abs(np.fft.rfft(x * np.hanning(len(x))))
    freqs = np.fft.rfftfreq(len(x), 1.0 / SR)
    total = mag.sum() + 1e-9
    return float((mag * freqs).sum() / total)


def extract_features(win: np.ndarray) -> np.ndarray:
    """Turn a captured tap window into a fixed-length feature vector."""
    x = win.astype(np.float64)
    x = x - x.mean()
    peak = float(np.abs(x).max()) + 1e-9
    energy_db = 20.0 * math.log10(peak)
    x = x / peak

    onset = PRE
    early = x[onset:onset + int(0.015 * SR)]
    late = x[onset + int(0.060 * SR):]

    feats: list[float] = []
    feats.extend(_log_bands(x, 60, 18000, 20))
    feats.extend(_log_bands(early, 100, 18000, 12))
    feats.extend(_log_bands(late, 100, 12000, 12))

    # Decay shape: normalised log RMS across six slices of the tap.
    slices = np.array_split(x[onset:], 6)
    rms = np.array([math.log(float(np.sqrt((s ** 2).mean())) + 1e-9) for s in slices])
    feats.extend(rms - rms.max())

    c_early, c_late = _centroid(early), _centroid(late)
    feats.append(c_early / 1000.0)
    feats.append(c_late / 1000.0)
    feats.append((c_early - c_late) / 1000.0)

    e_early = float(np.sqrt((early ** 2).mean())) + 1e-9
    e_late = float(np.sqrt((late ** 2).mean())) + 1e-9
    feats.append(math.log(e_late / e_early))          # direct-to-reverberant
    feats.append(float((np.diff(np.sign(x[onset:])) != 0).mean()) * 10.0)
    feats.append(energy_db / 10.0)

    return np.asarray(feats, dtype=np.float64)


# --------------------------------------------------------------------------
# Classifier
# --------------------------------------------------------------------------

@dataclass
class Sample:
    label: str
    feats: list[float]


class KNN:
    """Standardised-euclidean k-nearest-neighbour with distance weighting."""

    def __init__(self, k: int = 5) -> None:
        self.k = k
        self.samples: list[Sample] = []
        self._X: np.ndarray | None = None
        self._y: list[str] = []
        self._mean = None
        self._std = None

    def add(self, label: str, feats: np.ndarray) -> None:
        self.samples.append(Sample(label, feats.tolist()))
        self._X = None

    def clear(self, label: str | None = None) -> None:
        if label is None:
            self.samples = []
        else:
            self.samples = [s for s in self.samples if s.label != label]
        self._X = None

    def counts(self) -> dict[str, int]:
        return {z: sum(1 for s in self.samples if s.label == z) for z in ZONES}

    def _fit(self) -> None:
        if self._X is not None or not self.samples:
            return
        X = np.array([s.feats for s in self.samples], dtype=np.float64)
        self._mean = X.mean(axis=0)
        self._std = X.std(axis=0)
        self._std[self._std < 1e-6] = 1e-6
        self._X = (X - self._mean) / self._std
        self._y = [s.label for s in self.samples]

    def ready(self) -> bool:
        c = self.counts()
        return sum(1 for z in ZONES if c[z] >= 3) >= 2

    def predict(self, feats: np.ndarray) -> tuple[str, dict[str, float]] | None:
        self._fit()
        if self._X is None or len(self._X) < 2:
            return None
        q = (feats - self._mean) / self._std
        dist = np.sqrt(((self._X - q) ** 2).sum(axis=1))
        k = min(self.k, len(dist))
        idx = np.argsort(dist)[:k]
        weights: dict[str, float] = {z: 0.0 for z in ZONES}
        for i in idx:
            weights[self._y[i]] += 1.0 / (float(dist[i]) + 1e-6)
        total = sum(weights.values()) + 1e-9
        scores = {z: weights[z] / total for z in ZONES}
        best = max(scores, key=scores.get)
        return best, scores

    def cross_val(self) -> float | None:
        """Leave-one-out accuracy — an honest read on how well this setup works."""
        if len(self.samples) < 8:
            return None
        X = np.array([s.feats for s in self.samples], dtype=np.float64)
        y = [s.label for s in self.samples]
        mean, std = X.mean(axis=0), X.std(axis=0)
        std[std < 1e-6] = 1e-6
        Z = (X - mean) / std
        correct = 0
        for i in range(len(Z)):
            dist = np.sqrt(((Z - Z[i]) ** 2).sum(axis=1))
            dist[i] = np.inf
            k = min(self.k, len(dist) - 1)
            idx = np.argsort(dist)[:k]
            weights: dict[str, float] = {}
            for j in idx:
                weights[y[j]] = weights.get(y[j], 0.0) + 1.0 / (float(dist[j]) + 1e-6)
            if max(weights, key=weights.get) == y[i]:
                correct += 1
        return correct / len(Z)

    def to_json(self) -> str:
        return json.dumps({"k": self.k, "samples": [s.__dict__ for s in self.samples]})

    def load_json(self, text: str) -> None:
        data = json.loads(text)
        self.k = data.get("k", 5)
        self.samples = [Sample(s["label"], s["feats"]) for s in data.get("samples", [])]
        self._X = None


# --------------------------------------------------------------------------
# Audio capture + onset detection
# --------------------------------------------------------------------------

@dataclass
class Engine:
    model: KNN = field(default_factory=KNN)
    events: queue.Queue = field(default_factory=queue.Queue)

    mode: str = "predict"          # "predict" or "train"
    train_label: str = "TL"
    sensitivity: float = 50.0      # 0-100, higher = easier to trigger

    level: float = 0.0
    running: bool = False

    def __post_init__(self) -> None:
        self._ring = np.zeros(RING, dtype=np.float32)
        self._ring_i = 0
        self._pre = np.zeros(PRE, dtype=np.float32)
        self._capturing = False
        self._cap: list[np.ndarray] = []
        self._cap_len = 0
        self._last_tap = 0.0
        self._noise = 1e-4
        self._hp_state = 0.0
        self._work: queue.Queue = queue.Queue()
        self._stream = None
        self._lock = threading.Lock()

    # -- thresholds ------------------------------------------------------
    @property
    def _abs_floor(self) -> float:
        """Absolute trigger floor on the high-passed block RMS.

        Measured ambient noise on this machine peaks around 0.014 after the
        high pass, so even the most sensitive setting stays above that or the
        detector free-runs on room noise.
        """
        s = max(0.0, min(100.0, self.sensitivity)) / 100.0
        return float(10 ** (-0.8 - 1.0 * s))   # 0.158 (hard knock) .. 0.016 (light)

    def _callback(self, indata, frames, time_info, status) -> None:  # noqa: ARG002
        block = indata[:, 0].astype(np.float32)
        n = len(block)

        # First difference acts as a cheap high pass. Taps are broadband
        # transients; room rumble and fan noise sit low and get suppressed.
        # Vectorised on purpose — no per-sample Python loop in an audio callback.
        hp = np.diff(block, prepend=np.float32(self._hp_state))
        self._hp_state = float(block[-1])
        rms = float(np.sqrt((hp ** 2).mean()))
        self.level = rms

        end = self._ring_i + n
        if end <= RING:
            self._ring[self._ring_i:end] = block
        else:
            first = RING - self._ring_i
            self._ring[self._ring_i:] = block[:first]
            self._ring[:end - RING] = block[first:]
        self._ring_i = end % RING

        if self._capturing:
            self._cap.append(block.copy())
            self._cap_len += n
            if self._cap_len >= POST:
                win = np.concatenate([self._pre] + self._cap)[:WIN]
                self._capturing = False
                self._cap = []
                self._cap_len = 0
                if len(win) == WIN:
                    self._work.put(win)
            return

        now = time.monotonic()
        if rms > max(self._noise * 8.0, self._abs_floor) and (now - self._last_tap) > REFRACTORY:
            # Snapshot the pre-onset audio now, while it is still the newest
            # thing in the ring; the buffer has already moved on by the time
            # the capture finishes.
            lin = np.concatenate([self._ring[self._ring_i:], self._ring[:self._ring_i]])
            self._pre = lin[-(n + PRE):-n].copy() if n + PRE <= RING else np.zeros(PRE, dtype=np.float32)
            self._last_tap = now
            self._capturing = True
            self._cap = [block.copy()]
            self._cap_len = n
        else:
            self._noise = 0.995 * self._noise + 0.005 * rms

    # -- worker ----------------------------------------------------------
    def _worker(self) -> None:
        while self.running:
            try:
                win = self._work.get(timeout=0.2)
            except queue.Empty:
                continue
            try:
                feats = extract_features(win)
            except Exception as exc:  # noqa: BLE001
                self.events.put({"type": "error", "message": str(exc)})
                continue

            peak = float(np.abs(win).max())
            with self._lock:
                if self.mode == "train":
                    self.model.add(self.train_label, feats)
                    self.events.put({
                        "type": "trained",
                        "label": self.train_label,
                        "counts": self.model.counts(),
                        "peak": peak,
                        "accuracy": self.model.cross_val(),
                    })
                else:
                    result = self.model.predict(feats)
                    if result is None:
                        self.events.put({"type": "untrained", "peak": peak})
                    else:
                        best, scores = result
                        self.events.put({
                            "type": "tap",
                            "zone": best,
                            "scores": scores,
                            "peak": peak,
                        })

    # -- lifecycle -------------------------------------------------------
    def start(self, device=None) -> None:
        if self.running:
            return
        self.running = True
        self._stream = sd.InputStream(
            samplerate=SR, channels=1, blocksize=BLOCK,
            dtype="float32", callback=self._callback, device=device,
        )
        self._stream.start()
        threading.Thread(target=self._worker, daemon=True).start()

    def stop(self) -> None:
        self.running = False
        if self._stream is not None:
            self._stream.stop()
            self._stream.close()
            self._stream = None

    # -- state -----------------------------------------------------------
    def state(self) -> dict:
        with self._lock:
            return {
                "mode": self.mode,
                "train_label": self.train_label,
                "sensitivity": self.sensitivity,
                "counts": self.model.counts(),
                "ready": self.model.ready(),
                "accuracy": self.model.cross_val(),
                "running": self.running,
            }


MODEL_PATH = Path(__file__).parent / "model.json"
