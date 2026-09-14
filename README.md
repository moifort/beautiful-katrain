# Moyo

Native macOS interface for [KaTrain](https://github.com/sanderland/katrain), in SwiftUI.

![Moyo](docs/images/moyo-go.png)

## What it does

- Play KataGo with all sixteen KaTrain AI modes — human-like, period style, calibrated rank,
  influence, territory, tenuki and the rest
- Live score graph, read from the player's side
- End of game: two passes, dead stones proposed from KataGo's ownership then adjustable by
  click, Japanese or Chinese scoring
- Collapsible sidebar, native menus and shortcuts, Liquid Glass

## How it works

```
Moyo.app  ──JSON lines over stdin/stdout──>  bridge.py  ──>  katrain.core  ──>  katago
      (SwiftUI)                                           (Python)     (pip, unmodified)
```

The bridge owns the state, the app owns the pixels. No go rule is written in Swift.

## Build

Requires macOS 26+ on Apple Silicon, Xcode, Python 3.11+, and `cmake`, `ninja`
and `pkgconf` from Homebrew.

```bash
git clone https://github.com/moifort/moyo-go.git
cd moyo-go
python3 -m venv .venv
.venv/bin/pip install -r bridge/requirements.txt
./app/Scripts/build-katago.sh        # ~20 min, once
./app/Scripts/build-app.sh
open app/build/Moyo.app
```

`build-katago.sh` compiles KataGo with Abseil, protobuf and libzip linked
statically, and refuses to finish if the binary keeps any non-system dependency.
Homebrew's own `katago` carries 84 Homebrew dylibs and cannot be shipped.

The bundle is self-contained — interpreter, engine, models and configuration all
live inside it, because the App Store sandbox forbids reaching outside. It weighs
about 250 MB, most of it the two KataGo models.

To verify a built bundle end to end, from inside its own sandbox:

```bash
./app/build/Moyo.app/Contents/MacOS/Moyo --smoke
```

## Develop

`MOYO_DEV_ROOT` runs the bridge from the repository's virtual environment
instead of the bundle, and leaves `~/.katrain/config.json` in charge of the
engine — so a game played this way behaves exactly like KaTrain.

## Test

```bash
.venv/bin/python -m pytest bridge/tests
swift test --package-path app
```

## Limits

Apple Silicon only. No SGF, no analysis mode, no teaching mode — see `TODO.md`.

Territory scoring is the one go rule implemented here — KaTrain derives its final score from
KataGo's ownership and has no notion of a stone marked dead.

## License

MIT, same as KaTrain. KataGo ships separately under its own licence.
