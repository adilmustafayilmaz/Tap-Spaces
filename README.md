<div align="center">

<img src="docs/icon.png" width="112" alt="Tap Spaces">

# Tap Spaces

**Tap the desk around your MacBook. It works out which zone you hit, and fires the keyboard shortcut you bound to it.**

No extra hardware. No sensors. Just the microphone that is already there.

<img src="https://img.shields.io/badge/macOS-14%2B-000000?style=flat-square" alt="macOS 14+">
<img src="https://img.shields.io/badge/version-0.1.0%20beta-orange?style=flat-square" alt="0.1.0 beta">
<img src="https://img.shields.io/badge/signed-Developer%20ID-blue?style=flat-square" alt="Signed">
<img src="https://img.shields.io/badge/notarised-Apple-blue?style=flat-square" alt="Notarised">

</div>

<br>

<div align="center">
<img src="docs/toast.png" width="620" alt="Notification confirming a tap fired a shortcut">
</div>

<br>

Knock twice on the left side of your desk and the previous desktop slides in.
Knock on the right and the next one does. The laptop never moves, your hands
never leave the desk, and nothing is attached to anything.

---

## Install

```bash
brew tap adilmustafayilmaz/tap
brew trust adilmustafayilmaz/tap
brew install --cask tap-spaces
```

`brew trust` is needed because Homebrew treats third-party taps as untrusted by
default. It marks this tap as allowed to load and grants nothing else.

The app is signed with a Developer ID certificate and notarised by Apple, so it
opens without a Gatekeeper warning.

---

## How it works

The desk around the laptop is divided into four zones:

```
      Top Left  |  Top Right
     -----------+-----------
    Bottom Left | Bottom Right
           (MacBook)
```

macOS exposes the MacBook microphone array as a **single beamformed channel**:

```
$ system_profiler SPAudioDataType
    MacBook Pro Microphone:
      Input Channels: 1
```

One channel means there is no delay between channels to compare, which means
time-difference-of-arrival triangulation is impossible. There is no direction to
compute.

So Tap Spaces classifies each tap by its **acoustic fingerprint** instead. Where
you hit the desk changes four things at once:

| Cue | What changes |
|---|---|
| Distance | Amplitude, and how much high frequency survives the trip |
| Resonance | Every point excites a different mix of table modes |
| Direct-to-reverberant ratio | Rises as the source moves away from the mic |
| Attack and decay | Set by the contact point and the path the sound takes out |

Every tap becomes a 56-dimension vector — log-spectrum bands measured separately
over the full window, the attack and the tail; the decay envelope across six
slices; spectral centroid; direct-to-reverberant ratio; zero-crossing rate.

The band values are mean-removed, so the model reads *where* you hit rather than
*how hard*. Classification is a distance-weighted k-nearest-neighbour over
standardised features. It trains instantly and needs no dependencies.

---

## Setting it up

<table>
<tr>
<td width="50%" valign="top">

<img src="docs/onboarding.png" alt="First-run introduction">

**First run** walks through the two permissions the app needs — microphone to
hear the taps, accessibility to send the keystrokes — and then hands over to
calibration.

</td>
<td width="50%" valign="top">

<img src="docs/main.png" alt="Calibration and settings window">

**Calibration** teaches the app your desk. Pick a zone, tap that spot 20 to 30
times, repeat for the zones you want. Live mode fills each tile in proportion to
its score, so you can see the model deciding.

</td>
</tr>
</table>

The accuracy figure is leave-one-out cross-validation: every sample is scored
against a model built without it, never against itself.

**You do not have to calibrate all four zones.** Two zones on the same side works.
So does one, though a single zone cannot discriminate — every tap is then read as
that zone, which turns the app into a single desk-wide trigger.

Fewer zones are easier to tell apart. Choosing between two is markedly more
reliable than choosing between four.

---

## Limits

Worth knowing before you decide this is for you.

- **The setup has to stay put.** Move the laptop or the desk and the fingerprint
  changes. Recalibrate.
- **Surface matters.** Hard resonant wood separates well. Thick felt or heavy
  glass damps the differences and the zones converge.
- **Left and right beat top and bottom.** Top and bottom zones can sit at similar
  distances from the microphone. If accuracy is poor, spread the zones further
  apart.
- **Do not type while calibrating.** Keystrokes get recorded as samples.
- **Raise the confidence floor** for any zone bound to something you cannot undo.
- **More samples, better results.** This is a beta; the model gets meaningfully
  sharper the more taps you give it.

The app is not sandboxed. It posts synthetic key events to other applications and
no sandbox entitlement permits that, which is also why it ships outside the Mac
App Store.

---

## Build from source

```bash
git clone https://github.com/adilmustafayilmaz/Tap-Spaces.git
cd Tap-Spaces/native
./build.sh --install
```

Requires Xcode command line tools. `build.sh` redraws the app icon, compiles,
runs the self-test, assembles the bundle and signs it — with a Developer ID
certificate if one is installed, ad-hoc otherwise.

### Verification

```bash
.build/release/TapSpaces --selftest
```

Checks the FFT and band mapping, loudness invariance (the same tap at 0.25x and
2.5x amplitude has to land in the same place), k-NN accuracy, leave-one-out
cross-validation, JSON round-tripping and key formatting. It runs on every build.

### Releasing

```bash
./release.sh
```

Builds, archives, submits to the Apple notary service, staples the ticket and
re-archives the stapled copy. Notary credentials are read from a Keychain
profile, never from the command line or this repository.

---

## Repository layout

| Path | Contents |
|---|---|
| `native/Sources/TapSpaces/` | The macOS app — Swift, SwiftUI, AVAudioEngine, Accelerate |
| `native/icon/make-icon.swift` | Draws the app icon; every size is drawn separately rather than downscaled |
| `native/README.md` | Architecture, permissions and release notes |
| `tap_engine.py`, `server.py`, `web/` | The original Python prototype |

The Python prototype came first and validated the approach with numpy and a
browser UI over server-sent events. It still runs with `./run.sh`. Its feature
vectors are not interchangeable with the Swift ones — Accelerate requires
power-of-two FFT sizes, so the framing differs — and calibration does not
transfer between the two.

---

<div align="center">
<sub>The interface is currently Turkish only.</sub>
</div>
