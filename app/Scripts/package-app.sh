#!/bin/bash
# Emballe Moyo.app dans un .pkg signé, le seul format qu'accepte l'App Store macOS.
#
# `xcodebuild -exportArchive` ferait ça sur un projet Xcode ; Moyo est un paquet
# SwiftPM et n'a pas d'archive. `productbuild` part donc directement du bundle déjà
# assemblé et signé par build-app.sh.
#
# Deux certificats sont en jeu, et les confondre est l'erreur classique :
# *Apple Distribution* scelle l'application, *3rd Party Mac Developer Installer*
# scelle l'installeur. Celui-ci ne signe jamais l'autre.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BUNDLE="${1:-$ROOT/app/build/Moyo.app}"
PKG="${2:-$ROOT/app/build/Moyo.pkg}"
INSTALLER_IDENTITY="${MOYO_INSTALLER_IDENTITY:-}"

[ -d "$BUNDLE" ] || { echo "bundle introuvable : $BUNDLE" >&2; exit 1; }

# Un bundle dont la signature ne tient pas produirait un .pkg que l'App Store
# refuse après coup, sans rien dire d'utile. Autant s'en apercevoir ici.
codesign --verify --deep --strict "$BUNDLE"

if [ -z "$INSTALLER_IDENTITY" ]; then
  echo "MOYO_INSTALLER_IDENTITY absent : .pkg non signé, bon pour un essai local" >&2
  productbuild --component "$BUNDLE" /Applications "$PKG"
else
  productbuild --component "$BUNDLE" /Applications --sign "$INSTALLER_IDENTITY" "$PKG"
  pkgutil --check-signature "$PKG" >/dev/null
fi

echo "==> $PKG ($(du -sm "$PKG" | cut -f1) Mo)"
