"""Local web UI for the tap localizer.

Serves a single page and pushes tap events to it over server-sent events.
Uses only the standard library so the whole thing runs on numpy + sounddevice.
"""

from __future__ import annotations

import json
import queue
import sys
import threading
import webbrowser
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

import sounddevice as sd

from tap_engine import MODEL_PATH, ZONES, Engine

HERE = Path(__file__).parent
PORT = 8777

engine = Engine()
_subscribers: list[queue.Queue] = []
_sub_lock = threading.Lock()


def _broadcast(msg: dict) -> None:
    with _sub_lock:
        targets = list(_subscribers)
    for q in targets:
        try:
            q.put_nowait(msg)
        except queue.Full:
            pass


def _pump() -> None:
    """Move engine events onto every connected browser."""
    while True:
        msg = engine.events.get()
        _broadcast(msg)


def _levels() -> None:
    """Low-rate level meter so the user can see the mic is actually alive."""
    import time
    while True:
        time.sleep(0.1)
        _broadcast({"type": "level", "value": engine.level})


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, *args) -> None:  # noqa: ARG002 - quiet console
        pass

    # -- helpers ---------------------------------------------------------
    def _send(self, code: int, body: bytes, ctype: str) -> None:
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    def _json(self, obj: dict, code: int = 200) -> None:
        self._send(code, json.dumps(obj).encode(), "application/json")

    def _body(self) -> dict:
        length = int(self.headers.get("Content-Length") or 0)
        if not length:
            return {}
        try:
            return json.loads(self.rfile.read(length))
        except json.JSONDecodeError:
            return {}

    # -- routes ----------------------------------------------------------
    def do_GET(self) -> None:  # noqa: N802
        if self.path == "/":
            html = (HERE / "web" / "index.html").read_bytes()
            self._send(200, html, "text/html; charset=utf-8")
        elif self.path == "/state":
            self._json(engine.state())
        elif self.path == "/events":
            self._stream()
        else:
            self._send(404, b"not found", "text/plain")

    def do_POST(self) -> None:  # noqa: N802
        body = self._body()
        if self.path == "/mode":
            mode = body.get("mode")
            if mode in ("train", "predict"):
                engine.mode = mode
            label = body.get("label")
            if label in ZONES:
                engine.train_label = label
            self._json(engine.state())
        elif self.path == "/sensitivity":
            engine.sensitivity = float(body.get("value", 50))
            self._json(engine.state())
        elif self.path == "/clear":
            engine.model.clear(body.get("label"))
            self._json(engine.state())
        elif self.path == "/save":
            MODEL_PATH.write_text(engine.model.to_json())
            self._json({"ok": True, "path": str(MODEL_PATH)})
        elif self.path == "/load":
            if MODEL_PATH.exists():
                engine.model.load_json(MODEL_PATH.read_text())
                self._json(engine.state())
            else:
                self._json({"error": "kayıtlı model yok"}, 404)
        else:
            self._send(404, b"not found", "text/plain")

    def _stream(self) -> None:
        q: queue.Queue = queue.Queue(maxsize=64)
        with _sub_lock:
            _subscribers.append(q)
        self.send_response(200)
        self.send_header("Content-Type", "text/event-stream")
        self.send_header("Cache-Control", "no-cache")
        self.send_header("Connection", "keep-alive")
        self.end_headers()
        try:
            while True:
                try:
                    msg = q.get(timeout=15)
                    payload = f"data: {json.dumps(msg)}\n\n"
                except queue.Empty:
                    payload = ": keepalive\n\n"
                self.wfile.write(payload.encode())
                self.wfile.flush()
        except (BrokenPipeError, ConnectionResetError):
            pass
        finally:
            with _sub_lock:
                if q in _subscribers:
                    _subscribers.remove(q)


def main() -> None:
    try:
        info = sd.query_devices(kind="input")
        print(f"Giriş cihazı: {info['name']}  ({info['max_input_channels']} kanal)")
    except Exception as exc:  # noqa: BLE001
        print(f"Mikrofon bulunamadı: {exc}", file=sys.stderr)
        sys.exit(1)

    if MODEL_PATH.exists():
        engine.model.load_json(MODEL_PATH.read_text())
        print(f"Model yüklendi: {engine.model.counts()}")

    try:
        engine.start()
    except Exception as exc:  # noqa: BLE001
        print(f"Ses akışı açılamadı: {exc}", file=sys.stderr)
        print("Terminal'e mikrofon izni verildiğinden emin ol: "
              "Sistem Ayarları > Gizlilik ve Güvenlik > Mikrofon", file=sys.stderr)
        sys.exit(1)

    threading.Thread(target=_pump, daemon=True).start()
    threading.Thread(target=_levels, daemon=True).start()

    server = ThreadingHTTPServer(("127.0.0.1", PORT), Handler)
    server.daemon_threads = True
    url = f"http://127.0.0.1:{PORT}/"
    print(f"Arayüz: {url}   (durdurmak için Ctrl+C)")
    threading.Timer(0.8, lambda: webbrowser.open(url)).start()
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nkapatılıyor...")
    finally:
        engine.stop()


if __name__ == "__main__":
    main()
