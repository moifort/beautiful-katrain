# TODO

Things deliberately left out of the first Mac App Store release of Moyo Go.
Each entry says what it is and why it was deferred, so the reasoning survives.

## Product

- **Nerd mode.** A toggle that surfaces what the engine is actually doing: visit
  count, playouts, raw win rate, thread count, time per move. The first release
  ships a frozen engine configuration and no settings at all, because the AI mode
  already governs playing strength and every extra knob is a way to degrade the
  experience.

- **Localisation.** The interface is hardcoded French (`Button("Nouvelle partie…")`
  and friends). The App Store listing is worldwide, so the strings should move to a
  String Catalog with English alongside French.

- **SGF import and export.** No way in or out of a game record today.

- **Analysis mode.** Review a finished game move by move with KataGo's evaluation.

- **Teaching mode.** KaTrain's per-move feedback on mistakes and better options.

## Marketing

- **Landing page.** A page advertising the app and linking to its App Store listing.

## Packaging

- **Raise the deployment target to macOS 27.** The first release targets macOS 26
  because App Store Connect rejects binaries built against beta SDKs, and the
  macOS 27 SDK only ships in Xcode beta. Bump once Xcode 27 is public.

- **Adaptive thread count.** Derive KataGo's thread count from the core count at
  launch, so entry-level Macs and Ultras both behave sensibly.

- **Optional model download.** The two KataGo models are ~190 MB of the ~270 MB
  bundle. Downloading them on first launch would shrink the app, at the cost of a
  network entitlement, a progress UI, and a dependency on a third-party URL.

- **Track upstream KaTrain.** `katrain.core` is vendored into the bundle. New KaTrain
  releases need to be pulled in deliberately, and the Kivy shim re-checked against
  them.

## Out of scope

- **Intel and universal builds.** Apple Silicon only, by design.
- **iOS and iPadOS.** macOS only, by design.
