# Beautiful KaTrain

Une interface macOS native pour [KaTrain](https://github.com/sanderland/katrain), écrite en
SwiftUI.

![Beautiful KaTrain](docs/images/beautiful-katrain.png)

## Pourquoi

KaTrain est un excellent outil d'entraînement au go, mais son interface est construite avec
Kivy : widgets dessinés à la main, pas de menus natifs, rien qui ressemble à une application
Mac. Ce projet remplace **uniquement la couche d'interface**, sans toucher à la logique.

## Comment

Deux processus, et une frontière nette entre les deux.

```
BeautifulKaTrain.app  ──JSON-lines sur stdin/stdout──>  bridge.py  ──>  katrain.core  ──>  KataGo
      (SwiftUI)                                          (Python)      (intact, via pip)
```

**Le pont possède l'état, l'application possède les pixels.** Aucune règle du go n'est écrite
en Swift : l'application ne sait pas si un coup est légal, ne compte pas les prisonniers, ne
détecte pas le ko. Elle envoie une intention, reçoit un état, le dessine. Toute divergence de
comportement avec KaTrain est donc un bug du pont, jamais de l'interface.

Le cœur de KaTrain est consommé comme dépendance (`katrain==1.20.0` depuis PyPI). Aucun
fichier du paquet n'est modifié, copié ou patché, et les mises à jour amont restent
applicables.

## Ce que ça fait

- Jouer contre KataGo, avec les seize modes de KaTrain — modèle humain, style d'époque,
  niveau calibré, influence, territoire, tenuki…
- Graphe de score en temps réel, lu du côté du joueur
- Fin de partie : deux passes, pierres mortes proposées d'après l'*ownership* de KataGo puis
  ajustables au clic, comptage japonais ou chinois
- Barre latérale rétractable, menus et raccourcis natifs, Liquid Glass

## Installation

Prérequis : macOS 26 ou plus récent, Xcode, Python 3.11+, et KataGo avec un modèle.

```bash
brew install katago
```

Puis :

```bash
git clone https://github.com/moifort/beautiful-katrain.git
cd beautiful-katrain
python3 -m venv .venv
.venv/bin/pip install -r bridge/requirements.txt
./app/Scripts/build-app.sh
open app/build/BeautifulKaTrain.app
```

La configuration du moteur est lue dans `~/.katrain/config.json`, partagé avec KaTrain : si
KaTrain fonctionne chez vous, l'application aussi.

## Tests

```bash
.venv/bin/python -m pytest bridge/tests
swift test --package-path app
```

## Limites

L'application n'est **pas distribuable** en l'état : le chemin du projet est inscrit dans son
`Info.plist` au moment du build et le pont s'exécute depuis l'environnement virtuel local.
Embarquer un interpréteur Python dans le bundle est un travail à part entière, reporté.

Hors périmètre pour l'instant : chargement et sauvegarde SGF, mode analyse, coups suggérés,
points de teaching, variations, horloge.

Une seule règle du go est réimplémentée ici, le comptage territorial, parce que KaTrain déduit
son score final de l'*ownership* de KataGo et n'a aucune notion de pierre déclarée morte par
un joueur. Elle vit dans le pont, en Python, sous tests de position — jamais côté Swift.

## Licence

MIT, comme KaTrain. KataGo est distribué séparément et sous sa propre licence.
