"""Chemins du moteur imposés par le bundle.

Hors bundle, le pont lit sa configuration dans `~/.katrain/config.json`, partagé
avec KaTrain. Dans l'application distribuée, le sandbox coupe cet accès et tout
vit à l'intérieur du bundle : ces variables sont le seul moyen pour l'application
de dire au pont où elle a rangé le binaire et les modèles.
"""

#: Variable d'environnement -> clé de la section `engine` de KaTrain.
_BUNDLE_VARIABLES = {
    "MOYO_KATAGO": "katago",
    "MOYO_MODEL": "model",
    "MOYO_HUMAN_MODEL": "humanlike_model",
    "MOYO_CONFIG": "config",
}


def bundle_engine_overrides(environment):
    """Les surcharges à appliquer à la section `engine`, vide hors bundle.

    Une variable absente ou vide est ignorée plutôt qu'appliquée : un script de
    développement qui exporte la variable sans la renseigner ne doit pas effacer
    la configuration de l'utilisateur.
    """
    return {
        key: environment[name]
        for name, key in _BUNDLE_VARIABLES.items()
        if environment.get(name)
    }
