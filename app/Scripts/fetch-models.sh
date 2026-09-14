#!/bin/bash
# Récupère les deux réseaux KataGo et vérifie qu'ils sont bien ceux attendus.
#
# Les 190 Mo de modèles ne peuvent pas vivre dans le dépôt. Sur une machine de
# développement ils sont déjà là, posés par Homebrew et par KaTrain ; sur un runner
# GitHub il n'y a rien, et c'est ce script qui comble.
#
# Les empreintes sont figées ici. Une URL peut se mettre à servir autre chose sans
# prévenir, et un réseau substitué produirait une application qui joue — mal, ou
# différemment — sans que rien sur le chemin ne le signale.
set -euo pipefail

DEST="${1:-${MOYO_MODEL_CACHE:-$HOME/.cache/moyo/models}}"
mkdir -p "$DEST"

PLAY_URL="${MOYO_PLAY_MODEL_URL:-https://media.katagotraining.org/uploaded/networks/models/kata1/kata1-b18c384nbt-s9996604416-d4316597426.bin.gz}"
PLAY_SHA="9d7a6afed8ff5b74894727e156f04f0cd36060a24824892008fbb6e0cba51f1d"

HUMAN_URL="${MOYO_HUMAN_MODEL_URL:-https://github.com/lightvector/KataGo/releases/download/v1.15.0/b18c384nbt-humanv0.bin.gz}"
HUMAN_SHA="637746e44f0efe00ad1245a50aa9bbf0716efe364c43965ead97bd6835d84ab5"

fetch() {
  local name="$1" url="$2" want="$3" path="$DEST/$1"
  if [ -f "$path" ] && [ "$(shasum -a 256 "$path" | cut -d' ' -f1)" = "$want" ]; then
    echo "    $name déjà présent et conforme"
    return
  fi
  echo "==> $name"
  curl --fail --location --retry 3 --retry-delay 5 --progress-bar -o "$path.part" "$url"
  local got
  got="$(shasum -a 256 "$path.part" | cut -d' ' -f1)"
  if [ "$got" != "$want" ]; then
    rm -f "$path.part"
    echo "empreinte inattendue pour $name" >&2
    echo "  attendue : $want" >&2
    echo "  obtenue  : $got" >&2
    exit 1
  fi
  mv "$path.part" "$path"
}

fetch play.bin.gz "$PLAY_URL" "$PLAY_SHA"
fetch human.bin.gz "$HUMAN_URL" "$HUMAN_SHA"

# Ce que build-app.sh lira, pour que l'appelant n'ait pas à connaître ces chemins.
echo "MOYO_PLAY_MODEL=$DEST/play.bin.gz"
echo "MOYO_HUMAN_MODEL_FILE=$DEST/human.bin.gz"
