# Tap Spaces

Tap the table around your MacBook. Tap Spaces works out which zone you hit from
the built-in microphone alone and fires the keyboard shortcut you assigned to it.

```
   Sol Üst  │  Sağ Üst
   ─────────┼─────────
   Sol Alt  │  Sağ Alt
        (MacBook in the middle)
```

Menu bar only — no Dock icon, no app switcher entry.

## Install

```bash
brew tap adilmustafayilmaz/tap
brew trust adilmustafayilmaz/tap
brew install --cask tap-spaces
```

`brew trust` is required because Homebrew treats third-party taps as untrusted
by default.

Then open `TapSpaces.app`. On first launch it walks you through both permissions
and calibration. Requires macOS 14 or later.

The app is signed with a Developer ID certificate and notarised by Apple, so it
opens without a Gatekeeper warning. It is **not** sandboxed — it posts synthetic
key events to other applications, which no sandbox entitlement permits. That is
also why it ships outside the Mac App Store.

### Build from source

```bash
cd native
./build.sh --install     # requires Xcode command line tools
```

## How it works

macOS exposes the MacBook microphone array as a **single beamformed channel**:

```
$ system_profiler SPAudioDataType
    MacBook Pro Microphone:
      Input Channels: 1
```

One channel means no inter-channel delay, which means time-difference-of-arrival
triangulation is impossible. There is no direction to compute.

So each tap is classified by its **acoustic fingerprint** instead. Where you hit
the table changes:

- **Distance** — amplitude, and how much high frequency survives the trip
- **Which resonances fire** — every point excites a different mix of table modes
- **Direct-to-reverberant ratio** — rises as the source moves away
- **Attack and decay shape** — set by the contact point and the path out

Each tap becomes a 56-dimension vector: log-spectrum bands over the full window,
the attack, and the tail separately; decay envelope across six slices; spectral
centroid; direct-to-reverberant ratio; zero-crossing rate. The band values are
mean-removed, so the model reads *where* you hit rather than *how hard*.

Classification is a distance-weighted k-nearest-neighbour (k=5) over standardised
features. It trains instantly, needs few samples, and pulls in no dependencies.

Reported accuracy is leave-one-out cross-validation — each sample scored against
a model that excludes it, never against itself.

## Limits

- **The setup has to stay put.** Move the laptop or the table and the fingerprint
  changes; recalibrate.
- **Table surface matters.** Hard resonant wood separates well. Thick felt or
  heavy glass damps the differences and the zones converge.
- **Left/right beats top/bottom.** Top and bottom zones can sit at similar
  distances from the microphone. If accuracy is poor, spread the zones further
  apart.
- **Don't type during calibration** — keystrokes get recorded as samples.
- **Raise the confidence floor** if a zone is bound to something you can't undo.

## Repository layout

| Path | What |
|---|---|
| `native/` | The macOS app (Swift, SwiftUI, AVAudioEngine, Accelerate) |
| `native/README.md` | Build, permissions, architecture, release notes |
| `tap_engine.py`, `server.py`, `web/` | Original Python prototype |

The Python prototype came first and validated the approach with numpy and a
browser UI over server-sent events. It still runs:

```bash
./run.sh    # http://127.0.0.1:8777/
```

Its feature vectors are not interchangeable with the Swift ones — Accelerate
requires power-of-two FFT sizes, so the framing differs. Calibration does not
transfer between the two.

## Verification

```bash
cd native
.build/release/TapSpaces --selftest
```

Checks the FFT and band mapping, loudness invariance (the same tap at 0.25× and
2.5× amplitude must land in the same place), k-NN accuracy, leave-one-out
cross-validation, JSON round-tripping, and key formatting. `build.sh` runs it on
every build.
