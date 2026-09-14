#!/bin/bash
# Assemble le chargement Python embarqué dans l'application.
#
# Part d'une distribution python-build-standalone, l'élague de tout ce qui ne
# sert pas au pont, puis y dépose katrain.core, le shim Kivy et le pont.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SOURCE_PYTHON="$ROOT/vendor/python"
SITE_PACKAGES="$ROOT/.venv/lib/python3.13/site-packages"
OUT="${1:-$ROOT/app/build/payload}"

[ -d "$SOURCE_PYTHON" ] || { echo "manque $SOURCE_PYTHON (voir vendor/)" >&2; exit 1; }
[ -d "$SITE_PACKAGES/katrain" ] || { echo "manque katrain dans $SITE_PACKAGES" >&2; exit 1; }

echo "==> Copie de l'interpréteur"
rm -rf "$OUT"
mkdir -p "$OUT"
cp -R "$SOURCE_PYTHON" "$OUT/python"
BEFORE=$(du -sm "$OUT/python" | cut -f1)

echo "==> Élagage"
LIB="$OUT/python/lib/python3.13"
# Modules d'interface, de test et d'installation : aucun n'est atteignable depuis le pont.
rm -rf "$LIB/test" "$LIB/idlelib" "$LIB/tkinter" "$LIB/turtledemo" "$LIB/lib2to3" \
       "$LIB/ensurepip" "$LIB/distutils" "$LIB/pydoc_data" \
       "$LIB/site-packages/pip" "$LIB/site-packages/pip-"* \
       "$LIB/config-3.13-darwin" \
       "$OUT/python/include" "$OUT/python/share"
rm -f "$LIB/lib-dynload/_tkinter"*.so "$OUT/python/lib/libpython3.13.a"
find "$OUT/python" -name "__pycache__" -type d -prune -exec rm -rf {} + 2>/dev/null || true
find "$OUT/python" -name "*.pyc" -delete 2>/dev/null || true
AFTER=$(du -sm "$OUT/python" | cut -f1)
echo "    ${BEFORE} Mo -> ${AFTER} Mo"

echo "==> Dépôt du code"
CODE="$OUT/python/lib/python3.13/site-packages"

# katrain : le cœur, les constantes de thème dont lang.py dépend, et l'i18n que
# rank_label utilise pour les modes à rang calibré. Le reste du paquet (gui, img,
# sounds, fonts, KataGo, models) ne sert qu'à l'application Kivy amont.
mkdir -p "$CODE/katrain/gui"
# config.json porte les valeurs par défaut que KaTrainBase charge au démarrage :
# sans lui, la session n'a pas de section « engine » à surcharger.
cp "$SITE_PACKAGES/katrain/__init__.py" "$SITE_PACKAGES/katrain/config.json" "$CODE/katrain/"
cp -R "$SITE_PACKAGES/katrain/core" "$CODE/katrain/"
cp -R "$SITE_PACKAGES/katrain/i18n" "$CODE/katrain/"
cp "$SITE_PACKAGES/katrain/gui/__init__.py" "$SITE_PACKAGES/katrain/gui/theme.py" "$CODE/katrain/gui/"

cp -R "$SITE_PACKAGES/pysgf" "$CODE/"
# Les shims tiennent lieu de kivy (36 Mo, inutile sans interface) et de chardet
# (LGPL-2.1, et jamais appelé faute de lecture de SGF).
cp -R "$ROOT/bridge/shims/"* "$CODE/"
# Le pont reste un dossier de scripts plutôt qu'un paquet : ses modules
# s'importent à plat, et `python .../bridge/bridge.py` met ce dossier en tête de
# sys.path tout seul. L'empaqueter forcerait à réécrire ses imports et mettrait
# des noms aussi génériques que « protocol » ou « session » dans site-packages.
mkdir -p "$OUT/bridge"
cp "$ROOT"/bridge/*.py "$OUT/bridge/"

find "$CODE" -name "__pycache__" -type d -prune -exec rm -rf {} + 2>/dev/null || true
find "$CODE" -name "*.pyc" -delete 2>/dev/null || true

echo "==> $OUT/python  ($(du -sm "$OUT/python" | cut -f1) Mo)"
