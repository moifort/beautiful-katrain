"""`Observable` sert de classe de base à `Lang`, l'objet d'i18n de KaTrain.

Kivy s'en sert pour relier des widgets à une propriété ; `Lang.fbind` intercepte
le cas `"_"` (la traduction) et délègue le reste au parent. Sans widgets, il n'y
a rien à relier : les méthodes existent pour que la délégation aboutisse, et ne
font rien.
"""


class Observable:
    def __init__(self, *args, **kwargs):
        super().__init__()

    def fbind(self, name, func, *args):
        return 0

    def funbind(self, name, func, *args):
        return None

    def dispatch(self, name, *args, **kwargs):
        return None
