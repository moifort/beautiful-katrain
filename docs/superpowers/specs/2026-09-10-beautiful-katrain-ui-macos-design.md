# Beautiful KaTrain — jalon 1 : jouer contre l'IA

Date : 2026-09-10
Statut : validé

## 1. Objectif

Remplacer la couche d'interface de KaTrain (Kivy) par une application macOS SwiftUI
native, sans toucher à la logique métier. Le jalon 1 couvre une seule chose : jouer
une partie contre KataGo, avec le graphe de score en temps réel.

Les jalons ultérieurs (analyse de SGF, mode teaching, édition de variations) ne sont
pas spécifiés ici, mais le protocole du jalon 1 est conçu pour les accueillir sans
rupture.

## 2. Principe directeur

**Le pont possède l'état, l'app possède les pixels.**

Aucune règle du go n'est écrite en Swift. L'application ne sait pas si un coup est
légal, ne compte pas les prisonniers, ne détecte pas le ko. Elle envoie une
intention, reçoit un état, et le dessine. Toute divergence de comportement avec
KaTrain amont est donc un bug du pont, jamais de l'interface.

## 3. Architecture

Deux processus : une app SwiftUI qui lance un pont Python en sous-processus et
communique avec lui par tubes.

### 3.1 Le cœur KaTrain — dépendance, pas fork

`katrain==1.20.0` installé depuis PyPI dans un environnement virtuel. Aucun fichier
du paquet n'est modifié, copié ou patché. Les mises à jour amont restent applicables.

Kivy reste une dépendance transitive : quatre modules du cœur l'importent
(`base_katrain.py` pour `Config` et `JsonStore`, `engine.py` pour `platform`,
`lang.py` et `game_node.py` pour `Theme`). Ces imports sont satisfaits par
l'installation du paquet ; aucune fenêtre, boucle d'événements ou fournisseur
graphique Kivy n'est démarré.

### 3.2 Le pont — `bridge/bridge.py`

Sous-classe headless de `KaTrainBase` qui instancie `KataGoEngine` et `Game`, et
expose un protocole JSON-lines sur stdin/stdout. Il ne contient aucune logique de go :
il traduit des commandes en appels au cœur et sérialise l'état résultant.

Points d'accroche vérifiés dans le source 1.20.0 :

| Élément | Emplacement | Usage par le pont |
|---|---|---|
| `update_state()` | appelé par `engine.py:380` derrière un `getattr` défensif | hook de notification : l'analyse d'un nœud a progressé |
| `controls.set_status()` | appelé par `game.py` sur les chemins teaching et édition | le pont expose un objet `controls` factice qui absorbe tout appel |
| `Game.play(Move)` | `game.py:208` | joue un coup ; lève `IllegalMoveException` |
| `Move` | classe de `pysgf` | `Move(coords=(col, row))`, `Move(coords=None)` pour une passe |
| `GameNode.score` | `game_node.py` | `scoreLead` vu de Noir ; `None` tant que l'analyse manque |
| `GameNode.analysis_complete` | `game_node.py:281` | l'analyse du nœud est terminée |
| `generate_ai_move(game, strategy, settings)` | `ai.py:1739` | produit le coup de l'IA |
| `Game.prisoner_count` | `game.py:315` | prisonniers par couleur |
| `Game.end_result` | `game.py:308` | résultat final une fois la partie terminée |

L'objet `controls` factice est indispensable : le cœur y accède sans vérification
préalable sur certains chemins. Il implémente `set_status()` et expose un
`move_tree` inerte, tous deux sans effet.

### 3.3 L'app — `BeautifulKaTrain`

Application SwiftUI, cible macOS 26, Swift 6 en concurrence stricte. Elle lance le
pont via `Process`, écrit des commandes sur son stdin et lit ses événements sur
stdout de façon asynchrone. Un unique modèle `@Observable @MainActor` détient le
dernier état reçu ; les vues en dérivent.

## 4. Protocole

JSON-lines : une commande par ligne sur stdin, un événement par ligne sur stdout.
Chaque commande porte un `id` entier croissant ; les événements provoqués par une
commande réémettent cet `id`. Les événements spontanés (analyse, mort du moteur)
portent `id: null`.

Le pont envoie toujours l'état complet, jamais un delta. Une partie de 300 coups
produit un état de quelques kilooctets — la simplicité prime sur l'économie, et cela
rend la désynchronisation impossible.

### 4.1 Commandes

```
{"id":1,"cmd":"new_game","size":19,"komi":6.5,"rules":"japanese",
 "human_color":"B","ai_strategy":"ai:human","ai_settings":{"human_kyu_rank":8}}
{"id":2,"cmd":"play","row":3,"col":15}
{"id":3,"cmd":"pass"}
{"id":4,"cmd":"undo"}
{"id":5,"cmd":"resign"}
{"id":6,"cmd":"state"}
{"id":7,"cmd":"quit"}
```

`undo` annule les coups un à un jusqu'à ce que le trait revienne au joueur humain,
soit deux coups dans le cas courant. Formulé ainsi plutôt qu'en « annule une paire »,
il reste correct quand l'IA ouvre la partie, quand un joueur a passé, et au tout
premier coup.

`row` et `col` sont indexés à partir de zéro, origine en haut à gauche telle
qu'affichée. Le pont assure seul la conversion vers les coordonnées `pysgf`.

### 4.2 Événements

```
{"event":"ready","id":null,"engine":"katago 1.16.3","model":"b18c384nbt"}
{"event":"state","id":2, ...}
{"event":"thinking","id":2,"value":true}
{"event":"score","id":null,"move_number":47,"score_lead":2.4}
{"event":"error","id":2,"code":"illegal_move","message":"..."}
{"event":"engine_failed","id":null,"message":"..."}
```

Charge utile de `state` :

```json
{
  "event": "state",
  "id": 2,
  "size": 19,
  "stones": [{"row": 3, "col": 3, "color": "B"}],
  "to_play": "W",
  "move_number": 47,
  "last_move": {"row": 10, "col": 13},
  "prisoners": {"B": 3, "W": 1},
  "score_history": [0.0, 0.5, -1.0],
  "score_lead": 2.4,
  "human_color": "B",
  "status": "playing",
  "result": null
}
```

`status` vaut `playing` ou `finished`. `result` est `null` tant que la partie court,
puis la chaîne produite par `Game.end_result` (par exemple `B+2.5`).

`score_history` est indexé par numéro de coup, exprimé du point de vue de Noir :
positif signifie que Noir mène. Les entrées dont l'analyse n'est pas encore arrivée
valent `null`.

`last_move` est `null` après une passe ou en début de partie.

### 4.3 Séquence d'un coup

1. L'app envoie `play`.
2. Le pont appelle `game.play(Move(coords=...))`. Si `IllegalMoveException` est
   levée, il répond `error` avec le code `illegal_move` et s'arrête là : l'état
   n'a pas changé, l'app n'a rien à redessiner.
3. Le pont émet `state` (la pierre humaine est posée) puis `thinking: true`.
4. Le pont appelle `generate_ai_move()` et joue le coup retourné.
5. Le pont émet `thinking: false` puis `state`.

L'app n'orchestre jamais l'alternance des tours. Elle pose une pierre quand un
`state` le lui dit, pas quand l'utilisateur clique.

### 4.4 Le score arrive en différé

KataGo analyse de façon asynchrone : au moment où `state` est émis, le `scoreLead`
du coup qui vient d'être joué n'est généralement pas encore calculé. Bloquer le jeu
en attendant l'analyse rendrait l'application poussive.

Le pont surcharge donc `update_state()`, que l'engine appelle à chaque progression
d'analyse. À chaque appel, il parcourt les nœuds dont l'analyse est devenue complète
et émet un événement `score` par nœud nouvellement résolu. Le graphe se remplit
seul, avec un ou deux coups de retard, sans jamais retarder la pose des pierres.

Conséquence pour l'interface : une barre du graphe apparaît légèrement après la
pierre correspondante. C'est voulu et doit être animé, pas masqué.

## 5. L'interface

### 5.1 Fenêtre

`NavigationSplitView` à deux colonnes : barre latérale rétractable à gauche, goban à
droite. Fenêtre redimensionnable, taille minimale 720 × 560, plein écran pris en
charge. Le fond de la zone de jeu est sombre et fixe, indépendant du thème système :
un goban se lit mieux sur fond sombre, et le verre de la barre latérale devient
laiteux sur fond clair.

### 5.2 Barre latérale

Largeur 194 points, `.glassEffect()` appliqué après les modificateurs de mise en
forme, contenu groupé dans un `GlassEffectContainer`. De haut en bas :

1. Trait en cours — pastille de la couleur au trait, nom de la couleur, numéro de coup aligné à droite
2. Graphe de score — valeur numérique puis graphe en barres
3. Prisonniers — « 3 — 1 », Noir puis Blanc
4. Adversaire — stratégie et niveau
5. Actions, poussées en bas — « Annuler » et « Passer », `.buttonStyle(.glass)`

« Nouvelle partie » ne figure pas dans la barre latérale : c'est une action rare, elle
vit dans le menu Fichier.

### 5.3 Goban

Dessiné dans un `Canvas`, carré, centré, redimensionné avec la fenêtre. Le bois est
**opaque** — jamais de verre sous les pierres, la lisibilité prime. Le dernier coup
joué porte un cercle rouge. Aucune coordonnée n'est affichée sur les bords au
jalon 1.

Un clic sur une intersection envoie `play`. Aucune validation locale : si le coup est
illégal, le pont répond `error` et l'app se contente de ne rien changer.

### 5.4 Graphe de score

Barres en capsules, style Health : une seule teinte, deux intensités. Au-dessus de
la ligne médiane Noir mène, en dessous Blanc mène ; opacité pleine pour Noir, réduite
pour Blanc. La barre du coup courant est en blanc pur.

Les coups sont agrégés pour tenir dans la largeur disponible avec une largeur de
barre minimale de 3,5 points : à 47 coups, une barre représente deux coups ; sur une
partie longue le facteur d'agrégation augmente. La valeur agrégée est la moyenne des
`score_lead` du groupe, en ignorant les entrées non encore analysées.

Aucun axe, aucune graduation, aucune légende. La valeur exacte est donnée en chiffres
au-dessus du graphe ; le graphe ne porte que la forme.

Un `HStack` de `Capsule()`, chaque barre animable indépendamment : une nouvelle barre
pousse depuis la ligne médiane à chaque coup analysé.

### 5.5 Barre latérale repliée

Le repli utilise le bouton natif de la barre d'outils et le raccourci système
`⌃⌘S`. Quand la barre est repliée, trois éléments remontent dans la barre de titre,
alignés à droite : la pastille du trait, la valeur du score, et une version réduite
du graphe. Rien ne disparaît, tout se condense.

### 5.6 Menus et raccourcis

| Menu | Élément | Raccourci |
|---|---|---|
| Fichier | Nouvelle partie… | `⌘N` |
| Partie | Passer | `⌘P` |
| Partie | Annuler le coup | `⌘Z` |
| Partie | Abandonner | — |
| Présentation | Masquer la barre latérale | `⌃⌘S` |

« Nouvelle partie… » ouvre une feuille modale : taille (9 / 13 / 19), couleur du
joueur humain, niveau de l'IA en kyu. Le komi et les règles ne sont pas exposés au
jalon 1 ; ils prennent les valeurs de `~/.katrain/config.json`.

L'adversaire par défaut est `ai:human` avec `human_kyu_rank` issu de la
configuration existante — le modèle humanlike déjà présent sur la machine, qui donne
les parties les plus agréables.

## 6. Erreurs et cycle de vie

Le pont démarre avec l'app et s'arrête avec elle. `quit` est envoyé à la fermeture ;
au-delà d'une seconde sans sortie propre, le processus est terminé.

Trois situations d'erreur, traitées distinctement :

- **Coup illégal** — événement `error`, code `illegal_move`. Aucun retour visuel
  intrusif : la pierre ne se pose pas, c'est le seul retour nécessaire.
- **Moteur indisponible au démarrage** — binaire KataGo ou modèle introuvable.
  L'app affiche un écran d'erreur nommant le chemin manquant et n'ouvre pas de
  partie. Le pont émet `engine_failed` avant de rendre la main.
- **Pont mort en cours de partie** — l'app détecte la fermeture du tube, gèle le
  plateau et propose de relancer. L'état de la partie en cours est perdu au
  jalon 1 ; la sauvegarde SGF appartient à un jalon ultérieur.

Le pont écrit ses diagnostics sur stderr, jamais sur stdout, qui reste réservé au
protocole. L'app collecte stderr dans un fichier journal.

## 7. Périmètre

Dans le jalon 1 : nouvelle partie contre l'IA, pose de pierres, passe, annulation,
abandon, prisonniers, trait, numéro de coup, graphe de score en temps réel, résultat
final, barre latérale rétractable, menus et raccourcis natifs.

Hors jalon 1, explicitement : chargement et sauvegarde SGF, mode analyse, coups
suggérés, points de teaching, territoire, variations, arbre de coups, horloge,
coordonnées sur le plateau, sonorisation, réglages du moteur, internationalisation.

Le pont ne doit pas anticiper ces fonctions. Il doit en revanche ne rien faire qui
les empêche : d'où l'état complet à chaque envoi et l'identifiant de commande.

## 8. Structure des fichiers

```
beautiful-katrain/
├── bridge/
│   ├── bridge.py           point d'entrée, boucle de lecture stdin
│   ├── session.py          KaTrainBase headless, controls factice, cycle de vie
│   ├── protocol.py         encodage/décodage des commandes et événements
│   ├── serialize.py        Game -> charge utile d'état
│   ├── requirements.txt    katrain==1.20.0
│   └── tests/
└── BeautifulKaTrain/
    ├── BeautifulKaTrainApp.swift    scène, commandes de menu
    ├── Bridge/
    │   ├── BridgeProcess.swift      Process, tubes, lecture asynchrone
    │   ├── BridgeCommand.swift      commandes encodables
    │   └── BridgeEvent.swift        événements décodables
    ├── Model/
    │   └── GameSession.swift        @Observable @MainActor, dernier état reçu
    ├── Views/
    │   ├── GameWindow.swift         NavigationSplitView, barre d'outils
    │   ├── BoardView.swift          Canvas, géométrie, gestion du clic
    │   ├── SidebarView.swift        composition de la barre latérale
    │   ├── ScoreChart.swift         barres capsules et agrégation
    │   └── NewGameSheet.swift       feuille de nouvelle partie
    └── Tests/
```

`serialize.py` est isolé de `session.py` pour être testable sans moteur : on lui
passe un `Game` construit à la main et on vérifie la charge utile produite.

`BoardView.swift` ne contient que de la géométrie — conversion point/intersection et
tracé. Il ne connaît ni les règles ni le pont.

## 9. Tests

**Côté pont** — tests unitaires sans KataGo, avec un moteur factice :
sérialisation d'une position connue, coup illégal produisant `error` sans mutation
d'état, `undo` retirant bien deux coups, agrégation correcte de `score_history` avec
des trous, `controls` factice absorbant les appels du cœur sur le chemin teaching.

Un test d'intégration, marqué lent et non requis, joue dix coups contre le vrai
moteur et vérifie que la partie progresse.

**Côté app** — tests unitaires purs, sans interface : décodage des événements,
conversion point vers intersection aux quatre coins et hors plateau, agrégation des
barres du graphe pour 5, 47 et 300 coups.

L'interface elle-même est vérifiée à l'œil en exécutant l'application : le jalon 1
ne justifie pas de tests d'interface automatisés.

## 10. Risques

**Kivy sous Python 3.13.** L'environnement par défaut de la machine est 3.13.7 ;
si `kivy` ne s'y installe pas, l'environnement virtuel bascule sur 3.11. Aucune
conséquence sur le design. À vérifier en toute première étape d'implémentation, avant
d'écrire quoi que ce soit d'autre.

**Accès du cœur à `controls`.** Le stub couvre `set_status()` et `move_tree`, seuls
usages repérés sur les chemins du jalon 1. Un chemin non repéré produirait une
`AttributeError`. Le stub renvoie donc un objet inerte pour tout attribut inconnu
plutôt que de lever, et journalise l'accès sur stderr pour qu'il soit corrigé.

**Latence de l'analyse.** Si KataGo est lent, les barres du graphe accusent un retard
visible. Acceptable et assumé : les pierres, elles, ne sont jamais retardées.

**Empaquetage.** Le jalon 1 fonctionne depuis Xcode avec un environnement virtuel
local ; l'app n'est ni signée ni distribuable. Embarquer Python dans le bundle est un
travail à part entière, reporté à un jalon ultérieur.
