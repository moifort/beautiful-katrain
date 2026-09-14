"""`JsonStore` est le stockage clé/valeur adossé à un fichier JSON de Kivy.

`base_katrain.py` s'en sert pour la configuration : `put()` pour écrire une
section, `get()` pour la relire, et `dict(store)` pour tout charger d'un coup.
On reproduit ces trois usages et leur sémantique de persistance immédiate.
"""

import json
import os


class JsonStore:
    def __init__(self, filename, indent=None, **kwargs):
        self.filename = filename
        self.indent = indent
        self._data = {}
        if os.path.exists(filename):
            with open(filename, "r", encoding="utf-8") as handle:
                content = handle.read().strip()
            if content:
                self._data = json.loads(content)

    def _flush(self):
        directory = os.path.dirname(self.filename)
        if directory:
            os.makedirs(directory, exist_ok=True)
        with open(self.filename, "w", encoding="utf-8") as handle:
            json.dump(self._data, handle, indent=self.indent)

    def put(self, key, **values):
        self._data[key] = values
        self._flush()
        return True

    def get(self, key):
        return self._data[key]

    def delete(self, key):
        del self._data[key]
        self._flush()
        return True

    def exists(self, key):
        return key in self._data

    def keys(self):
        return self._data.keys()

    def find(self, **filters):
        for key, values in self._data.items():
            if all(values.get(name) == value for name, value in filters.items()):
                yield key, values

    def clear(self):
        self._data = {}
        self._flush()
        return True

    # `dict(store)` dans base_katrain.py passe par ces trois-là.
    def __getitem__(self, key):
        return self._data[key]

    def __iter__(self):
        return iter(self._data)

    def __len__(self):
        return len(self._data)

    def __contains__(self, key):
        return key in self._data
