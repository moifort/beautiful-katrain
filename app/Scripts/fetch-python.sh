#!/bin/bash
# Récupère l'interpréteur Python que le bundle embarquera, et vérifie que c'est
# bien celui attendu.
#
# L'application ne peut pas compter sur le Python de la machine : le sandbox de
# l'App Store lui interdit d'aller le chercher, et il n'y en a aucun de garanti
# sur un Mac. Elle embarque donc le sien, une distribution python-build-standalone
# relocalisable.
#
# L'empreinte est figée ici pour la même raison que celle des modèles : une URL
# peut se mettre à servir autre chose, et un interpréteur substitué s'exécuterait
# dans l'application sans que rien sur le chemin ne le signale.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DEST="${1:-${MOYO_PYTHON_DIST:-$ROOT/vendor/python}}"

VERSION="3.13.15"
RELEASE="20260901"
URL="${MOYO_PYTHON_URL:-https://github.com/astral-sh/python-build-standalone/releases/download/$RELEASE/cpython-$VERSION+$RELEASE-aarch64-apple-darwin-install_only.tar.gz}"
SHA="b9054a9d3d54f4cb5573d44907fddb29874b08909bde73f29f2868cf872223ee"

if [ -x "$DEST/bin/python3.13" ] && "$DEST/bin/python3.13" --version 2>&1 | grep -q "$VERSION"; then
  echo "    Python $VERSION déjà présent"
  exit 0
fi

echo "==> Python $VERSION"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# Une barre de progression devant un terminal, rien du tout dans un journal.
noise="--progress-bar"
[ -t 2 ] || noise="--silent --show-error"
# shellcheck disable=SC2086
curl --fail --location --retry 3 --retry-delay 5 $noise -o "$WORK/python.tar.gz" "$URL"

got="$(shasum -a 256 "$WORK/python.tar.gz" | cut -d' ' -f1)"
if [ "$got" != "$SHA" ]; then
  echo "empreinte inattendue pour la distribution Python" >&2
  echo "  attendue : $SHA" >&2
  echo "  obtenue  : $got" >&2
  exit 1
fi

tar xzf "$WORK/python.tar.gz" -C "$WORK"
rm -rf "$DEST"
mkdir -p "$(dirname "$DEST")"
mv "$WORK/python" "$DEST"
echo "==> $DEST ($("$DEST/bin/python3.13" --version))"
