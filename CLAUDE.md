# Conventions du projet

## TODO.md

**`TODO.md` est mis à jour à chaque push.** Toute idée écartée, tout report décidé en
cours de route y est consigné *avant* de pousser, avec la raison du report — c'est le
raisonnement qui doit survivre, pas seulement l'intention. Le fichier est écrit en
anglais, le reste de la documentation en français.

## Principe directeur

Le pont possède l'état, l'app possède les pixels. Aucune règle du go n'est écrite en
Swift : toute divergence de comportement avec KaTrain amont est un bug du pont.

## Tests

```bash
.venv/bin/python -m pytest bridge/tests
swift test --package-path app
```
