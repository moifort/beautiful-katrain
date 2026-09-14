# Import SGF et mode revue

Moyo sait jouer contre KataGo, il ne sait pas relire une partie. Cette spec ajoute
l'import d'un SGF, la navigation coup par coup, et l'affichage du meilleur coup de
KataGo à chaque position.

## Ce qu'on obtient

On ouvre un `.sgf`, la partie s'affiche entière à son dernier coup. Les flèches gauche
et droite reculent et avancent d'un coup. À chaque position, une pastille verte marque
le meilleur coup selon KataGo. Option+flèche droite pose ce coup sur le plateau et
descend la variante principale, un coup à chaque appui, alternant noir et blanc ;
Option+flèche gauche remonte.

## Décisions

| Question | Réponse | Raison |
|---|---|---|
| Fenêtrage | L'import remplace la partie courante | Une fenêtre = une `GameSession` = un KataGo. Une seconde fenêtre coûte 190 Mo de modèles |
| Marqueur | Une pastille pleine verte, convention KaTrain | Choisi sur maquette contre la pierre fantôme et les variantes chiffrées |
| Densité | Le meilleur coup seul, sans chiffre | Le plateau reste lisible ; la variante part de ce point |
| Visibilité | Permanente pendant la revue | Rien à maintenir, rien à apprendre |
| Analyse | Les 5 nœuds précédents en priorité, le reste en fond | Navigation utilisable avant la fin de l'analyse |
| Variante | La `pv` déjà calculée, pas d'analyse fraîche | Gratuit et instantané ; cohérent avec la pastille affichée |
| Import | ⌘O, glisser-déposer, et double-clic dans le Finder | Les trois |
| Transport | L'app envoie le **texte**, pas le chemin | Voir « Le pont ne lit aucun fichier » |

## Architecture

Le principe directeur ne bouge pas : le pont possède l'état, l'app possède les pixels.
Aucune règle du go n'est écrite en Swift — la variante d'Option+→ est **jouée** dans
l'arbre KaTrain, donc captures et ko se règlent en amont.

### Le pont, en trois fichiers

`session.py` fait 440 lignes et la revue lui en ajouterait 180. On découpe d'abord.

| Fichier | Rôle |
|---|---|
| `bridge/host.py` *(nouveau)* | La plomberie KaTrain : contrôles inertes, journal sur stderr, file de tâches, cycle du moteur, chemins du bundle |
| `bridge/session.py` | L'état, le mode, l'aiguillage. Perd la plomberie, gagne la revue |
| `bridge/review.py` *(nouveau)* | Fonctions pures : lire l'arbre, le meilleur coup, la variante, la progression |

`review.py` suit `serialize.py` et `scoring.py` : on lui passe des données, il rend des
données. Testable sans KataGo.

### Ce que KaTrain fournit déjà

- `KaTrainSGF.parse_sgf(texte)` rend l'arbre.
- `Game(self, engine, move_tree=root)` le charge **et lance seul** `analyze_all_nodes`
  en tâche de fond à `PRIORITY_GAME_ANALYSIS = -100`.
- `node.analyze(engine, priority=PRIORITY_DEFAULT)` fait doubler la file à un nœud.
- `node.candidate_moves[0]` porte le meilleur coup et sa `pv`, alternant les couleurs.

`request_analysis` n'a **aucun garde-fou contre les doublons** : chaque appel émet une
requête. La fenêtre prioritaire tient donc son propre registre des nœuds déjà propulsés.

### Le protocole

Trois commandes :

- `load_sgf {name, contents}` — bascule en revue, se place sur le dernier coup
- `goto {move_number}` — borné par le pont ; couvre ←, →, ⌘← et ⌘→
- `variation {step: +1 | -1}` — empile ou dépile un coup de la variante

Le `state` gagne, en revue seulement : `mode`, `move_count`, `game_info` (noms, rangs,
résultat, date), `variation_depth`, et `best_move` — `{row, col, points_lost}` ou `null`
tant que l'analyse n'est pas revenue. Un événement `analysis_progress {done, total}`
alimente la jauge.

`best_move` voyage dans le `state` plutôt que dans un événement séparé : en revue l'état
ne se réémet qu'à la navigation et à l'arrivée de l'analyse du nœud courant.

### Le pont ne lit aucun fichier

`bridge/shims/chardet/__init__.py` porte cette phrase : « L'application ne lit aucun SGF,
donc ce chemin n'est jamais emprunté. […] Si le jour vient d'ouvrir de vrais SGF, ce
fichier devra céder la place à une détection sérieuse. »

On garde la phrase vraie. L'app lit le fichier et envoie son **texte** ; le pont ne
touche jamais au disque. Trois bénéfices : aucune question sur l'héritage du sandbox par
le processus fils, aucun LGPL à embarquer, et la détection d'encodage passe par
`NSString(contentsOf:usedEncoding:)`, meilleure que « UTF-8 sinon Latin-1 ».

Prix consenti : la propriété `CA[]` du SGF est ignorée au profit de la détection système.
Ça ne peut désaccorder que des noms ou des commentaires, jamais les coups, qui sont en
ASCII.

### L'app

| Fichier | Rôle |
|---|---|
| `Model/SGFImport.swift` *(nouveau)* | URL → texte : accès sécurisé, décodage, erreurs |
| `Views/ReviewCommands.swift` *(nouveau)* | Le menu « Revue » et ses raccourcis |
| `Model/GameSession.swift` | `loadSGF`, `goto`, `stepVariation`, `isReviewing` |
| `Views/BoardView.swift` | La pastille verte, lue dans le `state` |
| `Views/SidebarView.swift` | Panneau de revue : noms, « Coup 143 / 210 », jauge |
| `Views/GameWindow.swift` | Cible de dépôt, alerte d'erreur |
| `Sources/Moyo/MoyoApp.swift` | Délégué d'application pour l'ouverture depuis le Finder |

Raccourcis : `←` `→` un coup, `⌘←` `⌘→` début et fin, `⌥→` `⌥←` la variante. Des éléments
de menu à raccourci nu plutôt qu'un `.onKeyPress` : découvrabilité, et `⌥` se montre. Ils
sont désactivés hors revue, et un élément désactivé ne consomme pas la touche — les
flèches restent aux réglages de la feuille « Nouvelle partie ».

Le bundle gagne l'entitlement `com.apple.security.files.user-selected.read-only`, un
`CFBundleDocumentTypes` et une `UTImportedTypeDeclaration` pour `.sgf`, que macOS ne
déclare pas.

## Deux corrections exigées par la fonctionnalité

1. `_emit_new_scores` parcourt `current_node.nodes_from_root`. En revue, placé au coup 10,
   il n'émettrait que 10 scores et le graphe resterait tronqué. Il doit parcourir la ligne
   principale entière.
2. `_emitted_scores` est indexé par `node.depth` — un nœud de variante partage sa
   profondeur avec un nœud de la ligne principale et corromprait le graphe. On n'émet de
   score que pour les nœuds de la ligne principale.

Et une lacune préexistante : `lastErrorMessage` est renseigné dans `GameSession` et
affiché nulle part. Sans l'alerte qui manque, un SGF illisible échoue en silence.

## Tests

- `bridge/tests/test_review.py` — les fonctions pures, sur des SGF écrits en dur et un
  nœud dont on fabrique l'`analysis` à la main. Aucun moteur.
- `bridge/tests/test_session_review.py` — le `FakeEngine` de `test_session_scoring.py`
  marche tel quel : bascule de mode, bornage de `goto`, élagage de la variante.
- `app/Tests/MoyoCoreTests/SGFImportTests.swift` — décodage UTF-8, Latin-1, tronqué.
- `BridgeEventTests.swift` — les champs nouveaux du `state`, et leur absence en jeu.

## Risques

| Risque | Parade |
|---|---|
| Un SGF rectangulaire (19×9) : `serialize.board_size` lève une `ValueError` | Rattrapée à l'import, rendue en `bad_sgf` lisible |
| Une partie de 400 coups : plusieurs minutes de moteur | La jauge le dit, la fenêtre prioritaire rend la navigation utilisable avant la fin |
| `request_analysis` abandonne sur les commandes `AE` | Ces nœuds restent sans pastille, le reste s'analyse |
| Un SGF à branches multiples | On suit `children[0]`. Consigné dans `TODO.md` |

## Hors périmètre

Le plateau est en lecture seule en revue — un clic ne fait rien, pas même sur la pastille.
Pas d'export SGF, pas de branches multiples, pas de commentaires, pas de mode
enseignement. Tout est consigné dans `TODO.md`.
