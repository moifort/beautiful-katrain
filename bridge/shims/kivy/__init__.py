"""Remplacement minimal de Kivy pour faire tourner `katrain.core` sans interface.

`katrain.core` n'utilise Kivy qu'en quatre points, aucun graphique. Les fournir
ici évite d'embarquer Kivy (36 Mo), pygame (LGPL) et ffpyplayer (FFmpeg) dans
une application distribuée.

Ce paquet n'a de sens que placé devant le vrai Kivy sur `sys.path`.
"""


class _Config:
    """`kivy.Config` ne sert qu'à régler la verbosité des logs de Kivy.

    Sans Kivy, il n'y a pas de logs à régler. On accepte les appels et on les
    ignore, plutôt que d'aller retoucher `base_katrain.py`.
    """

    def set(self, section, key, value):
        return None

    def get(self, section, key, default=None):
        return default

    def getint(self, section, key, default=0):
        return default

    def getboolean(self, section, key, default=False):
        return default


Config = _Config()
