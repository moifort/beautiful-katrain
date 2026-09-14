"""Remplacement minimal de `chardet`, que `pysgf` importe au chargement.

`pysgf.parser` n'appelle `chardet.detect()` qu'une fois, dans `from_file()`, pour
deviner l'encodage d'un SGF lu sur disque quand le fichier ne porte pas de
propriété `CA[]`. L'application ne lit aucun SGF, donc ce chemin n'est jamais
emprunté — mais l'import, lui, a lieu.

Embarquer le vrai chardet obligerait à redistribuer du LGPL-2.1, ce que la
distribution App Store rend au mieux inconfortable. On fournit donc la seule
fonction utilisée, avec une détection honnête et volontairement modeste : UTF-8
s'il décode, Latin-1 sinon — ce dernier accepte n'importe quel octet.

Si le jour vient d'ouvrir de vrais SGF, ce fichier devra céder la place à une
détection sérieuse sous licence permissive (`charset_normalizer`, MIT).
"""


def detect(byte_str):
    if isinstance(byte_str, memoryview):
        byte_str = byte_str.tobytes()
    try:
        byte_str.decode("utf-8")
    except UnicodeDecodeError:
        return {"encoding": "ISO-8859-1", "confidence": 0.5, "language": ""}
    return {"encoding": "utf-8", "confidence": 0.99, "language": ""}


def detect_all(byte_str, ignore_threshold=False):
    return [detect(byte_str)]
