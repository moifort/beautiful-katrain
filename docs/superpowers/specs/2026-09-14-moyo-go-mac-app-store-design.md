# Moyo Go — publication sur le Mac App Store

Date : 2026-09-14
Statut : validé

## 1. Objectif

Transformer une application qui ne tourne que sur la machine de son auteur en une
application distribuable sur le Mac App Store, sous un nom qui tient debout seul.

Le point de départ n'est pas distribuable pour deux raisons : le chemin du projet est
inscrit dans `Info.plist` sous la clé `BKTProjectRoot`, et le pont Python s'exécute
depuis le `.venv` du dépôt. Le point d'arrivée est un bundle autonome, sandboxé et
signé, qui ne dépend d'absolument rien d'installé sur la machine de l'utilisateur.

Le comportement de jeu ne change pas. Les seize modes d'IA de KaTrain, le graphe de
score, le comptage des pierres mortes fonctionnent à l'identique.

## 2. Décisions arrêtées

| Sujet | Décision |
|---|---|
| Nom App Store | **Moyo Go** — affiché « Moyo » sous l'icône |
| Identifiant | `com.thibaut.moyo` |
| Dépôt | `github.com/moifort/moyo-go` |
| Prix | Gratuit |
| Architecture | arm64 seulement — Apple Silicon M1 et plus |
| macOS minimum | **26.0** |
| Runtime | Python embarqué, Kivy remplacé par un shim |
| Modèles | Dans le bundle, ~190 Mo |
| Réglages moteur | Configuration figée, aucune UI de réglage |
| Langues | Anglais et français |

### Pourquoi macOS 26

`LSMinimumSystemVersion` est un plancher, pas un plafond : une application construite
pour macOS 26 tourne telle quelle sur macOS 27. Monter la cible ne ferait que retirer
des utilisateurs sans rien apporter. Elle ne bougera que le jour où une API exclusive à
une version plus récente deviendra nécessaire — ce n'est pas une dette, c'est le
réglage correct.

S'y ajoute une contrainte de calendrier : macOS 27 est en préversion et son SDK n'existe
que dans Xcode bêta, or **App Store Connect refuse les binaires compilés contre un SDK
bêta.** Viser 27 rendrait le projet non soumissible.

### Pourquoi un nom sans « KaTrain »

La guideline 5.2.1 sur la propriété intellectuelle s'applique entre projets, y compris
entre projets MIT. Le nom doit tenir seul ; la paternité de KaTrain et de KataGo est
portée par la description de la fiche et par un écran « À propos » — c'est par ailleurs
une obligation de leur licence MIT, pas une politesse.

## 3. Architecture du bundle

La chaîne de processus compte désormais deux étages, chacun héritant du sandbox de
son parent :

```
Moyo.app (sandbox)  →  python3.13 (sandbox + inherit)  →  katago (sandbox + inherit)
```

Le protocole JSON lines sur stdin/stdout ne change pas, `bridge/*.py` non plus.

```
Moyo.app/Contents/
├── Info.plist                    com.thibaut.moyo — LSMinimumSystemVersion 26.0
├── embedded.provisionprofile     profil Mac App Distribution
├── MacOS/Moyo                    exécutable Swift
├── Helpers/
│   ├── python3.13                python-build-standalone, Info.plist en section __TEXT
│   └── katago                    recompilé Metal, sans entraînement distribué
├── Frameworks/Python.framework/  stdlib élaguée, chaque .so signé
└── Resources/
    ├── Moyo.icns
    ├── analysis_config.cfg
    ├── models/                   kata1-b18c384nbt (93 Mo) + b18c384nbt-humanv0 (94 Mo)
    └── bridge/                   bridge/*.py, katrain/core vendoré, shim kivy, pysgf
```

Total estimé : **~270 Mo**.

Les deux modèles sont obligatoires : les modes human-like tirent leur policy de
`humanv0`, mais le score et l'ownership viennent du modèle principal.

## 4. Les quatre briques à fabriquer

### 4.1 Le shim Kivy

`katrain.core` importe Kivy, mais superficiellement — quatre points de contact, aucun
graphique :

| Import | Fichier | Remplacement |
|---|---|---|
| `kivy.Config` | `base_katrain.py:5` | no-op |
| `kivy.storage.jsonstore.JsonStore` | `base_katrain.py:6` | JSON dans le conteneur |
| `kivy.utils.platform` | `engine.py:11` | constante `"macosx"` |
| `kivy._event.Observable` | `lang.py:5` | classe vide |

Une cinquantaine de lignes suffisent, et le bundle se passe de Kivy (36 Mo), de pygame
(LGPL) et de ffpyplayer (FFmpeg) — trois dépendances dont deux posaient un problème de
licence en distribution.

`katrain/core` est vendoré tel quel. Sont exclus `gui/`, `img/`, `sounds/`, `fonts/`,
ainsi que le `KataGo/` et les `models/` que le paquet embarque déjà : 111 des 116 Mo.

### 4.2 KataGo redistribuable

Le binaire Homebrew **n'est pas redistribuable** : il est lié à une dizaine de dylibs
Homebrew — `libzip`, `protobuf`, tout Abseil — parce que Homebrew active
l'entraînement distribué.

Recompilation depuis les sources en `-DUSE_BACKEND=METAL -DBUILD_DISTRIBUTED=OFF`, ce
qui élimine protobuf et Abseil. Restent zlib et libzip, liés statiquement. Binaire
arm64, signé par nous.

### 4.3 BridgeLocation

`BridgeLocation.resolve` cherche aujourd'hui un dossier projet via la variable
`BEAUTIFUL_KATRAIN_ROOT` puis via `BKTProjectRoot`. Il résoudra désormais d'abord les
chemins internes au bundle, en gardant une variable d'environnement comme échappatoire
pour le développement local.

### 4.4 La configuration du moteur

Le pont lit aujourd'hui `~/.katrain/config.json`, partagé avec KaTrain. **Le sandbox
coupe cet accès**, et c'est irréversible : l'application aura sa propre configuration,
dans son conteneur.

Cette configuration est figée et embarquée. Les chemins qu'elle contient — binaire
`katago`, modèle de jeu, modèle human-like — sont aujourd'hui absolus et pointent vers
Homebrew et le dossier personnel ; ils devront être résolus au lancement relativement
au bundle, puis injectés dans la configuration passée à `KataGoEngine`.

Conséquence assumée : une partie jouée dans Moyo n'utilise plus les réglages moteur de
l'installation KaTrain de l'utilisateur, et ne les modifie plus.

## 5. Renommage

| Aujourd'hui | Demain |
|---|---|
| `Sources/BeautifulKaTrain{,Core}/` | `Sources/Moyo{,Core}/` |
| `Tests/BeautifulKaTrainCoreTests/` | `Tests/MoyoCoreTests/` |
| `com.thibaut.beautifulkatrain` | `com.thibaut.moyo` |
| `BEAUTIFUL_KATRAIN_ROOT` | `MOYO_DEV_ROOT` |
| `BKTProjectRoot` | supprimée |
| `Application Support/BeautifulKaTrain` | `Application Support/Moyo` |

## 6. Sandbox, entitlements et signature

L'application : `com.apple.security.app-sandbox`. **Aucune entitlement réseau** — le
choix d'embarquer les modèles rend l'application littéralement incapable de télécharger
quoi que ce soit, ce qui clôt d'avance la question de la guideline 2.5.2 et permet une
étiquette de confidentialité « aucune donnée collectée ».

Les deux helpers : **exactement** `com.apple.security.app-sandbox` et
`com.apple.security.inherit`. Toute entitlement supplémentaire sur un processus enfant
le fait avorter au démarrage.

La signature va de l'intérieur vers l'extérieur, sans quoi chaque signature externe
invalide les internes :

1. chaque `.so` et `.dylib` de `Python.framework`
2. `Helpers/python3.13`
3. `Helpers/katago`
4. `Python.framework`, puis le bundle avec le profil de provisioning
5. `productbuild` → `.pkg` → `notarytool`

Certificats à créer : *Apple Distribution* et *Mac Installer Distribution*.

## 7. Localisation

Les chaînes de l'interface sont en français, en dur dans les vues. Elles migrent vers
un String Catalog, avec l'anglais à côté du français — une trentaine de chaînes.

## 8. Tests

Les deux suites existantes restent vertes après le renommage. Trois ajouts :

- **Shim Kivy** — importer `katrain.core.ai`, `.engine` et `.game` avec le seul shim
  sur `sys.path`, et vérifier que le vrai Kivy n'est jamais chargé.
- **`BridgeLocation`** — résolution en mode bundle contre résolution en mode
  développement.
- **`Scripts/smoke-bundle.sh`** — lancer le python du bundle construit, enchaîner
  `new_game` → `play` → `state`, vérifier les événements ; puis `codesign --verify
  --deep --strict` et l'inspection des entitlements de chaque helper.

## 9. Risques

1. **KataGo en Metal sous sandbox.** Le seul risque capable d'invalider l'approche, et
   le seul qu'aucune documentation ne tranche. Il se prouve empiriquement, d'où la
   phase 0.
2. **L'identifiant de bundle du helper Python.** Piège documenté sur les forums Apple :
   sans `Info.plist` embarqué en section `__TEXT`, le système ne trouve pas
   d'identifiant à l'exécutable Python.
3. **La review sur la guideline 2.5.2.** Largement désamorcé par l'absence d'entitlement
   réseau. Précédent utile : *AI Go — Baduk, Weiqi* est publié sur l'App Store avec
   KataGo embarqué et hors ligne.

## 10. Découpage

| Phase | Contenu | Sort si elle échoue |
|---|---|---|
| **0** | Spike : `katago` Metal + Python dans un bundle signé et sandboxé | Tout le reste est à revoir |
| **1** | Renommage en Moyo | — |
| **2** | Bundle autonome et relocalisable | — |
| **3** | Sandbox, entitlements, chaîne de signature | — |
| **4** | App Store Connect : icône, fiche, captures, envoi | — |

La phase 0 ne produit rien d'utilisable. Elle existe pour que l'échec, s'il a lieu,
arrive avant qu'on ait construit quoi que ce soit par-dessus.

## 11. Fiche App Store

Catégorie Jeux › Plateau. Classification 4+. Gratuit. Confidentialité : aucune donnée
collectée. Description créditant KaTrain et KataGo, licences MIT reproduites.

## 12. Hors périmètre

SGF, mode analyse, mode teaching, nerd mode, réglages moteur, builds Intel ou
universels, iOS. Consignés dans `TODO.md` avec la raison de leur report.
