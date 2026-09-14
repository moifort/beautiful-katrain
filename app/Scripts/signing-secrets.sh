#!/bin/bash
# Confie à la CI de quoi signer : les identités de ce trousseau, et le profil.
#
# La CI démarre sur une machine vide et ne peut pas emprunter le trousseau de
# session. Il faut donc lui donner les certificats et leurs clés privées, exportés
# en .p12 puis encodés en base64.
#
#   ./app/Scripts/signing-secrets.sh ~/Downloads/Moyo.provisionprofile
#
# `security export` ne sait pas extraire une identité nommée : il exporte toutes
# celles du trousseau, ou rien. Le .p12 emporte donc aussi le certificat de
# développement, inutile à la CI mais inoffensif — c'est `MOYO_SIGN_IDENTITY` qui
# désigne lequel signe. Le trousseau demandera l'autorisation d'exporter les clés
# privées : c'est le seul moment où quelque chose vous sera demandé.
set -euo pipefail

PROFILE="${1:-}"
REPO="${MOYO_REPO:-moifort/moyo-go}"

command -v gh >/dev/null || { echo "gh manquant (brew install gh)" >&2; exit 1; }
gh auth status >/dev/null 2>&1 || { echo "gh non authentifié (gh auth login)" >&2; exit 1; }

if [ -z "$PROFILE" ] || [ ! -f "$PROFILE" ]; then
  cat >&2 <<'USAGE'
Il manque le profil de provisioning.

Sur developer.apple.com › Certificates, Identifiers & Profiles › Profiles, créez un
profil « Mac App Store » pour com.thibaut.moyo, téléchargez-le, puis relancez :

  ./app/Scripts/signing-secrets.sh ~/Downloads/Moyo.provisionprofile
USAGE
  exit 1
fi

identity_named() {
  security find-identity -v | grep "$1" | head -1 | sed 's/.*"\(.*\)"/\1/'
}

# Deux certificats, et les confondre est l'erreur classique : le premier scelle
# l'application, le second l'installeur. Aucun ne fait le travail de l'autre.
SIGN_IDENTITY="$(identity_named 'Apple Distribution')"
INSTALLER_IDENTITY="$(identity_named 'Installer')"

[ -n "$SIGN_IDENTITY" ] || {
  echo "aucun certificat « Apple Distribution » dans le trousseau" >&2; exit 1; }
[ -n "$INSTALLER_IDENTITY" ] || {
  echo "aucun certificat d'installeur (« 3rd Party Mac Developer Installer ») dans le trousseau" >&2
  exit 1; }

echo "==> Identités trouvées"
echo "    application : $SIGN_IDENTITY"
echo "    installeur  : $INSTALLER_IDENTITY"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
P12="$WORK/signing.p12"
PASSWORD="$(uuidgen)"

echo "==> Export du trousseau (une autorisation va être demandée)"
security export -t identities -f pkcs12 -P "$PASSWORD" -o "$P12"

echo "==> Dépôt des secrets sur $REPO"
base64 -i "$P12" | gh secret set MACOS_SIGNING_P12 --repo "$REPO"
printf '%s' "$PASSWORD" | gh secret set MACOS_SIGNING_P12_PASSWORD --repo "$REPO"
base64 -i "$PROFILE" | gh secret set MACOS_PROVISION_PROFILE --repo "$REPO"

# Les identités ne sont que des noms : des variables, pas des secrets. La CI doit
# les nommer à codesign et à productbuild.
gh variable set MOYO_SIGN_IDENTITY --repo "$REPO" --body "$SIGN_IDENTITY"
gh variable set MOYO_INSTALLER_IDENTITY --repo "$REPO" --body "$INSTALLER_IDENTITY"

echo "    MACOS_SIGNING_P12, MACOS_SIGNING_P12_PASSWORD, MACOS_PROVISION_PROFILE"
echo "    MOYO_SIGN_IDENTITY, MOYO_INSTALLER_IDENTITY"
echo
echo "Pour éprouver la chaîne sans consommer de numéro de build :"
echo "  gh workflow run release.yml --repo $REPO -f skip_upload=true"
