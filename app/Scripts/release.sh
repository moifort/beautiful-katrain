#!/bin/bash
# Publie Moyo, depuis ce Mac. Du tag à la revue Apple, en une commande.
#
#   ./app/Scripts/release.sh v1.0
#
# Pourquoi pas la CI : un runner GitHub a un GPU paravirtualisé. Il sait compiler
# et signer, il ne sait pas prouver qu'une partie se joue — et c'est précisément ce
# qu'une release doit garantir. Les tests unitaires, eux, tournent à chaque commit
# sur GitHub : ils n'ont besoin d'aucune machine particulière.
#
# Ce Mac a tout : KataGo déjà compilé, les modèles, les certificats dans le
# trousseau, un vrai GPU. Rien à confier à personne.
#
# Prérequis, une fois pour toutes :
#   - la fiche de l'application existe sur appstoreconnect.apple.com, avec sa
#     catégorie, sa classification d'âge, sa confidentialité et son prix ;
#   - un profil « Mac App Store » téléchargé, désigné par MOYO_PROVISION_PROFILE ;
#   - la clé App Store Connect : ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_PATH.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

TAG="${1:-}"
BUNDLE_ID="${MOYO_BUNDLE_ID:-com.thibaut.moyo}"
SKIP_UPLOAD="${MOYO_SKIP_UPLOAD:-0}"
SMOKE_ONLY="${MOYO_SMOKE_ONLY:-0}"

step() { printf '\n\033[1m==> %s\033[0m\n' "$1"; }
fail() { echo "release: $1" >&2; exit 1; }

# Le nom complet d'une identite du trousseau, tel que codesign l'attend.
identity_named() {
  security find-identity -v | grep "$1" | head -1 | sed -E 's/.*"(.*)"/\1/'
}

[ -n "$TAG" ] || fail "usage : ./app/Scripts/release.sh v1.0  (le tag doit exister et être annoté)"
git rev-parse "$TAG" >/dev/null 2>&1 || fail "le tag $TAG n'existe pas — git tag -a $TAG -m \"…\""

MARKETING="${TAG#v}"
BUILD="$(git rev-list --count "$TAG")"
NOTES="$(git tag -l --format='%(contents:body)' "$TAG")"
[ -n "$NOTES" ] || NOTES="$(git tag -l --format='%(contents:subject)' "$TAG")"
[ -n "$NOTES" ] || fail "le tag $TAG n'est pas annoté : ses notes seraient vides sur l'App Store"

# Publier autre chose que ce qui est taggé est l'erreur qu'on ne rattrape pas.
[ -z "$(git status --porcelain)" ] || fail "l'arbre de travail n'est pas propre"
[ "$(git rev-parse HEAD)" = "$(git rev-parse "$TAG^{commit}")" ] || fail "HEAD n'est pas sur $TAG"

echo "Moyo $MARKETING (build $BUILD), depuis $TAG"

step "Suites unitaires"
[ -d .venv ] || python3 -m venv .venv
.venv/bin/pip install --quiet -r bridge/requirements.txt
.venv/bin/python -m pytest bridge/tests -q
swift test --package-path app

step "KataGo"
# Une vingtaine de minutes à froid, quelques secondes ensuite.
./app/Scripts/build-katago.sh >/dev/null

step "Modèles"
# Vérifiés par empreinte : un réseau substitué produirait une application qui joue
# différemment sans que rien sur le chemin ne le signale.
eval "$(./app/Scripts/fetch-models.sh | grep '^MOYO_')"
export MOYO_PLAY_MODEL MOYO_HUMAN_MODEL_FILE

step "Assemblage"
if [ "$SMOKE_ONLY" = "1" ]; then
  echo "    MOYO_SMOKE_ONLY=1 : signature ad-hoc, pas de .pkg"
  unset MOYO_SIGN_IDENTITY MOYO_INSTALLER_IDENTITY MOYO_PROVISION_PROFILE || true
else
  [ -n "${MOYO_PROVISION_PROFILE:-}" ] \
    || fail "MOYO_PROVISION_PROFILE requis (voir l'en-tete de ce script)"
  [ -f "$MOYO_PROVISION_PROFILE" ] \
    || fail "profil introuvable : $MOYO_PROVISION_PROFILE"
  # Deux certificats, et les confondre est l'erreur classique : le premier scelle
  # l'application, le second l'installeur. Cherchés ici pour n'avoir rien a poser
  # a la main, mais une variable deja definie gagne.
  export MOYO_SIGN_IDENTITY="${MOYO_SIGN_IDENTITY:-$(identity_named 'Apple Distribution')}"
  export MOYO_INSTALLER_IDENTITY="${MOYO_INSTALLER_IDENTITY:-$(identity_named 'Installer')}"
  [ -n "$MOYO_SIGN_IDENTITY" ] || fail "aucun certificat « Apple Distribution » dans le trousseau"
  [ -n "$MOYO_INSTALLER_IDENTITY" ] || fail "aucun certificat d'installeur dans le trousseau"
  echo "    application : $MOYO_SIGN_IDENTITY"
  echo "    installeur  : $MOYO_INSTALLER_IDENTITY"
fi
MOYO_VERSION="$MARKETING" MOYO_BUILD_NUMBER="$BUILD" ./app/Scripts/build-app.sh release

# ── La barrière ───────────────────────────────────────────────────────────────
# Le bundle qu'on s'apprête à publier joue un coup contre KataGo, ouvre un
# enregistrement, le parcourt, et déroule la proposition du moteur — depuis son
# propre sandbox, seul endroit d'où la preuve vaut. Sort 1 à la première phase qui
# échoue, et `set -e` arrête tout là.
step "Barrière : le bundle joue et relit"
./app/build/Moyo.app/Contents/MacOS/Moyo --smoke

if [ "$SMOKE_ONLY" = "1" ]; then
  step "MOYO_SMOKE_ONLY=1 : on s'arrête après la barrière"
  exit 0
fi

step "Envoi à App Store Connect"
if [ "$SKIP_UPLOAD" = "1" ]; then
  echo "    MOYO_SKIP_UPLOAD=1 : .pkg gardé, rien d'envoyé"
  echo "    $ROOT/app/build/Moyo.pkg"
  exit 0
fi
: "${ASC_KEY_ID:?}" "${ASC_ISSUER_ID:?}" "${ASC_KEY_PATH:?}"
mkdir -p "$HOME/.appstoreconnect/private_keys"
cp "$ASC_KEY_PATH" "$HOME/.appstoreconnect/private_keys/AuthKey_${ASC_KEY_ID}.p8"
trap 'rm -f "$HOME/.appstoreconnect/private_keys/AuthKey_${ASC_KEY_ID}.p8"' EXIT
xcrun altool --upload-app --type macos \
  --file app/build/Moyo.pkg \
  --apiKey "$ASC_KEY_ID" --apiIssuer "$ASC_ISSUER_ID"

step "Attachement et soumission"
# `altool` ne fait que déposer un fichier : il n'apparaît sur aucune version et
# rien n'est soumis.
.venv/bin/pip install --quiet -r app/Scripts/requirements-release.txt
NOTES_FILE="$(mktemp)"
printf '%s\n' "$NOTES" > "$NOTES_FILE"
.venv/bin/python ./app/Scripts/submit-app.py \
  --bundle-id "$BUNDLE_ID" --version "$MARKETING" --build "$BUILD" \
  --notes-file "$NOTES_FILE"
rm -f "$NOTES_FILE"

step "Release GitHub"
if command -v gh >/dev/null && gh auth status >/dev/null 2>&1; then
  git push origin "$TAG"
  printf '%s\n' "$NOTES" | gh release create "$TAG" --title "Moyo $MARKETING" --notes-file - \
    || printf '%s\n' "$NOTES" | gh release edit "$TAG" --title "Moyo $MARKETING" --notes-file -
else
  echo "    gh absent ou non authentifié : release GitHub à faire à la main"
fi

step "Moyo $MARKETING ($BUILD) est en revue"
