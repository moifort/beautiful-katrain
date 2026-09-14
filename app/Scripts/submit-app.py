#!/usr/bin/env python3
"""Attache la build à sa version, pose les nouveautés, et soumet à la revue.

L'envoi du binaire par `altool` ne fait que déposer un fichier : il n'apparaît sur
aucune version, et rien n'est soumis. Ce script fait le reste par l'API App Store
Connect, sans fastlane — le dépôt n'a pas de Ruby et n'en veut pas pour ça.

Ce qu'il ne peut pas faire, et personne ne le peut par l'API : **créer la fiche de
l'application**. Elle doit exister sur appstoreconnect.apple.com, avec sa catégorie,
sa classification d'âge, sa politique de confidentialité et son prix — tout cela est
exigé avant la première soumission et n'existe qu'à l'interface web. Le script le
dit clairement plutôt que d'échouer sur un 404 obscur.

    ASC_KEY_ID=… ASC_ISSUER_ID=… ASC_KEY_PATH=… \
      ./app/Scripts/submit-app.py --bundle-id com.thibaut.moyo \
        --version 1.0 --build 42 --notes-file notes.txt
"""

import argparse
import json
import os
import sys
import time
import urllib.error
import urllib.request

import jwt

API = "https://api.appstoreconnect.apple.com/v1"
PLATFORM = "MAC_OS"


class Fatal(SystemExit):
    def __init__(self, message):
        super().__init__(f"submit: {message}")


def token() -> str:
    key_id = os.environ.get("ASC_KEY_ID")
    issuer = os.environ.get("ASC_ISSUER_ID")
    path = os.environ.get("ASC_KEY_PATH")
    if not (key_id and issuer and path):
        raise Fatal("ASC_KEY_ID, ASC_ISSUER_ID et ASC_KEY_PATH sont requis")
    with open(path) as handle:
        secret = handle.read()
    now = int(time.time())
    return jwt.encode(
        {"iss": issuer, "iat": now, "exp": now + 19 * 60, "aud": "appstoreconnect-v1"},
        secret,
        algorithm="ES256",
        headers={"kid": key_id, "typ": "JWT"},
    )


def call(method: str, path: str, body=None, bearer=None):
    url = path if path.startswith("http") else f"{API}{path}"
    data = json.dumps(body).encode() if body is not None else None
    request = urllib.request.Request(url, data=data, method=method)
    request.add_header("Authorization", f"Bearer {bearer}")
    if data:
        request.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(request) as response:
            raw = response.read()
            return json.loads(raw) if raw else {}
    except urllib.error.HTTPError as error:
        detail = error.read().decode(errors="replace")
        raise Fatal(f"{method} {url} → {error.code}\n{detail[:900]}") from error


def find_app(bearer: str, bundle_id: str) -> str:
    found = call("GET", f"/apps?filter[bundleId]={bundle_id}&limit=1", bearer=bearer)
    if not found.get("data"):
        raise Fatal(
            f"aucune application pour « {bundle_id} ».\n"
            "  L'API ne sait pas créer une fiche : il faut la créer une première fois sur\n"
            "  appstoreconnect.apple.com (nom, SKU, langue), puis y renseigner catégorie,\n"
            "  classification d'âge, confidentialité et prix. Ensuite ce script prend le relais."
        )
    return found["data"][0]["id"]


def wait_for_build(bearer: str, app_id: str, build_number: str, timeout: int) -> str:
    """Attend qu'App Store Connect ait fini de digérer le binaire.

    Une build en PROCESSING ne peut être attachée à rien. Le traitement prend de
    quelques minutes à une heure, sans rien annoncer : on interroge.
    """
    deadline = time.time() + timeout
    query = (
        f"/builds?filter[app]={app_id}&filter[version]={build_number}"
        "&limit=1&sort=-uploadedDate"
    )
    while time.time() < deadline:
        builds = call("GET", query, bearer=bearer).get("data") or []
        if builds:
            state = builds[0]["attributes"].get("processingState")
            if state == "VALID":
                return builds[0]["id"]
            if state in ("INVALID", "FAILED"):
                raise Fatal(f"la build {build_number} est en état {state}")
            print(f"submit: build {build_number} en {state}, on attend…", flush=True)
        else:
            print(f"submit: build {build_number} pas encore visible…", flush=True)
        time.sleep(60)
    raise Fatal(f"la build {build_number} n'est pas devenue exploitable en {timeout}s")


def version_for(bearer: str, app_id: str, marketing: str) -> str:
    existing = call(
        "GET",
        f"/apps/{app_id}/appStoreVersions?filter[versionString]={marketing}&limit=1",
        bearer=bearer,
    ).get("data") or []
    if existing:
        return existing[0]["id"]
    created = call(
        "POST",
        "/appStoreVersions",
        {
            "data": {
                "type": "appStoreVersions",
                "attributes": {"platform": PLATFORM, "versionString": marketing},
                "relationships": {"app": {"data": {"type": "apps", "id": app_id}}},
            }
        },
        bearer=bearer,
    )
    return created["data"]["id"]


def set_release_notes(bearer: str, version_id: str, notes: str) -> None:
    """Écrit les nouveautés dans chaque langue déjà déclarée.

    Une langue qu'on n'écrit pas garde ce qu'elle avait — c'est-à-dire rien sur une
    version neuve, et App Store Connect refuse alors la soumission. On les couvre
    donc toutes, avec le même texte : l'application est en français seulement, sa
    localisation est consignée dans TODO.md.
    """
    localizations = call(
        "GET", f"/appStoreVersions/{version_id}/appStoreVersionLocalizations", bearer=bearer
    ).get("data") or []
    if not localizations:
        raise Fatal("cette version n'a aucune langue déclarée ; ouvrez-la une fois sur le web")
    for localization in localizations:
        call(
            "PATCH",
            f"/appStoreVersionLocalizations/{localization['id']}",
            {
                "data": {
                    "type": "appStoreVersionLocalizations",
                    "id": localization["id"],
                    "attributes": {"whatsNew": notes},
                }
            },
            bearer=bearer,
        )
        print(f"submit: nouveautés posées pour {localization['attributes'].get('locale')}")


def attach_build(bearer: str, version_id: str, build_id: str) -> None:
    call(
        "PATCH",
        f"/appStoreVersions/{version_id}/relationships/build",
        {"data": {"type": "builds", "id": build_id}},
        bearer=bearer,
    )


def submit_for_review(bearer: str, app_id: str, version_id: str) -> None:
    """Crée une soumission de revue et la remet à Apple.

    Deux temps : la soumission naît ouverte, on y met la version, puis on la ferme.
    Une soumission déjà en cours pour cette application fait échouer la création, ce
    que le message d'erreur d'Apple dit clairement — on le laisse passer tel quel.
    """
    submission = call(
        "POST",
        "/reviewSubmissions",
        {
            "data": {
                "type": "reviewSubmissions",
                "attributes": {"platform": PLATFORM},
                "relationships": {"app": {"data": {"type": "apps", "id": app_id}}},
            }
        },
        bearer=bearer,
    )["data"]["id"]
    call(
        "POST",
        "/reviewSubmissionItems",
        {
            "data": {
                "type": "reviewSubmissionItems",
                "relationships": {
                    "reviewSubmission": {
                        "data": {"type": "reviewSubmissions", "id": submission}
                    },
                    "appStoreVersion": {
                        "data": {"type": "appStoreVersions", "id": version_id}
                    },
                },
            }
        },
        bearer=bearer,
    )
    call(
        "PATCH",
        f"/reviewSubmissions/{submission}",
        {
            "data": {
                "type": "reviewSubmissions",
                "id": submission,
                "attributes": {"submitted": True},
            }
        },
        bearer=bearer,
    )
    print(f"submit: soumission {submission} remise à la revue")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--bundle-id", required=True)
    parser.add_argument("--version", required=True, help="CFBundleShortVersionString")
    parser.add_argument("--build", required=True, help="CFBundleVersion")
    parser.add_argument("--notes-file", help="texte des nouveautés ; ignoré s'il est vide")
    parser.add_argument("--build-timeout", type=int, default=3600)
    parser.add_argument(
        "--no-submit",
        action="store_true",
        help="attache la build et pose les nouveautés, sans remettre à la revue",
    )
    args = parser.parse_args()

    bearer = token()
    app_id = find_app(bearer, args.bundle_id)
    print(f"submit: application {args.bundle_id} → {app_id}")

    build_id = wait_for_build(bearer, app_id, args.build, args.build_timeout)
    print(f"submit: build {args.build} exploitable → {build_id}")

    version_id = version_for(bearer, app_id, args.version)
    print(f"submit: version {args.version} → {version_id}")

    attach_build(bearer, version_id, build_id)
    print("submit: build attachée à sa version")

    notes = ""
    if args.notes_file and os.path.exists(args.notes_file):
        with open(args.notes_file) as handle:
            notes = handle.read().strip()
    if notes:
        set_release_notes(bearer, version_id, notes)
    else:
        print("submit: aucune note de version fournie, les langues gardent leur texte")

    if args.no_submit:
        print("submit: --no-submit, on s'arrête avant la revue")
        return 0
    submit_for_review(bearer, app_id, version_id)
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Fatal as fatal:
        print(fatal, file=sys.stderr)
        sys.exit(1)
