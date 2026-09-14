# Moyo

Native macOS interface for [KaTrain](https://github.com/sanderland/katrain), in SwiftUI.

![Moyo](docs/images/moyo-go.png)

## What it does

- Play KataGo with all sixteen KaTrain AI modes — human-like, period style, calibrated rank,
  influence, territory, tenuki and the rest
- Live score graph, read from the player's side
- End of game: two passes, dead stones proposed from KataGo's ownership then adjustable by
  click, Japanese or Chinese scoring
- Read a game record: open an SGF, walk it with the arrow keys, and see KataGo's own
  choice at each position. Option and the arrows walk the engine's continuation
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

To verify a built bundle end to end, from inside its own sandbox — it plays a move
and reads a record back, and exits non-zero on the first phase that fails:

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

## Release

Releases are made from a Mac, with one command:

```bash
git tag -a v1.0 -m "Ce qui change dans cette version…"
MOYO_PROVISION_PROFILE=~/Downloads/Moyo.provisionprofile \
ASC_KEY_ID=… ASC_ISSUER_ID=… ASC_KEY_PATH=… \
  ./app/Scripts/release.sh v1.0
```

The tag's annotation becomes the "What's New" text, so a version's notes live with
the version rather than in a changelog.

The chain: unit suites → KataGo → the models, fetched and checksummed → the signed
bundle and its `.pkg` → **the gate** → App Store Connect → attach the build and
submit for review.

The gate is `Moyo --smoke`. It plays a move against KataGo, opens a record, walks
it, and unrolls the engine's continuation — from inside the bundle's own sandbox,
the only place the proof is worth anything. It exits non-zero on the first phase
that fails, and the release stops there.

`MOYO_SMOKE_ONLY=1` stops after the gate and needs no certificate at all;
`MOYO_SKIP_UPLOAD=1` stops with the `.pkg` in hand.

CI runs the two unit suites and nothing else, on every commit
(`.github/workflows/test.yml`). It does not build the bundle and does not run the
gate: a GitHub runner's GPU is paravirtualised, so it can compile and sign but it
cannot show that a game is played — which is the one thing a release has to
guarantee. This Mac has everything anyway: KataGo compiled, the models, the
certificates in the keychain, a real GPU.

### Before the first release

The App Store Connect API cannot create an app record. Create it once on
appstoreconnect.apple.com — name, SKU, language — then set category, age rating,
privacy policy, pricing and screenshots there. Only then can a build be attached
and submitted.

## Limits

Apple Silicon only. Records can be read but not written, a review follows the main
line and ignores the record's branches and comments, and there is no teaching mode —
see `TODO.md`.

Territory scoring is the one go rule implemented here — KaTrain derives its final score from
KataGo's ownership and has no notion of a stone marked dead.

## License

MIT, same as KaTrain. KataGo ships separately under its own licence.
