#!/usr/bin/env python3
"""Transforme l'illustration brute en Moyo.icns.

Le modèle d'image rend un squircle sur fond blanc, avec son ombre portée peinte
dans l'image. Une icône macOS doit au contraire être transparente hors de sa
forme, sinon elle affiche un carré blanc dans le Dock et le système lui ajoute
une seconde ombre par-dessus la première.

On recadre donc sur la forme, on la masque, et on la repose aux proportions du
gabarit macOS : 824 points de contenu centrés dans une planche de 1024.

    .venv/bin/python app/Scripts/make-icon.py [source.png]
"""

import subprocess
import sys
import tempfile
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent.parent
SOURCE = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "app/Resources/icon/gemini/c-territoire.png"
ICONSET_SIZES = [16, 32, 64, 128, 256, 512, 1024]

CANVAS = 1024
CONTENT = 824  # gabarit macOS : 100 points de marge de chaque côté
#: Exposant de la superellipse. Apple n'emploie pas un rectangle arrondi mais une
#: courbe continue ; 5 en est une approximation fidèle à l'œil.
SQUIRCLE_EXPONENT = 5.0
#: Au-delà, un pixel est considéré comme faisant partie du fond blanc à jeter.
WHITE = 246
#: Le bord de la forme peinte par le modèle garde un liseré clair, et notre
#: superellipse ne coïncide pas au pixel près avec la sienne. On rogne un peu à
#: l'intérieur pour que ce liseré tombe hors du masque.
INSET = 0.055


def trim_to_shape(image):
    """Recadre sur la forme, en jetant le fond blanc et son ombre."""
    grey = image.convert("L")
    mask = grey.point(lambda v: 255 if v < WHITE else 0)
    box = mask.getbbox()
    if box is None:
        return image
    # Carré centré sur la forme : la découpe suivante suppose des côtés égaux.
    left, top, right, bottom = box
    side = max(right - left, bottom - top)
    cx, cy = (left + right) // 2, (top + bottom) // 2
    half = int(side // 2 * (1 - INSET))
    return image.crop((cx - half, cy - half, cx + half, cy + half))


def squircle_mask(size, supersample=4):
    """Masque alpha en superellipse, lissé par suréchantillonnage."""
    big = size * supersample
    mask = Image.new("L", (big, big), 0)
    pixels = mask.load()
    half = big / 2
    for y in range(big):
        ny = abs((y + 0.5 - half) / half)
        nyp = ny ** SQUIRCLE_EXPONENT
        if nyp > 1:
            continue
        for x in range(big):
            nx = abs((x + 0.5 - half) / half)
            if nx ** SQUIRCLE_EXPONENT + nyp <= 1:
                pixels[x, y] = 255
    return mask.resize((size, size), Image.LANCZOS)


def main():
    if not SOURCE.exists():
        sys.exit(f"source introuvable : {SOURCE}")

    art = trim_to_shape(Image.open(SOURCE).convert("RGB")).resize((CONTENT, CONTENT), Image.LANCZOS)
    art.putalpha(squircle_mask(CONTENT))

    icon = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    offset = (CANVAS - CONTENT) // 2
    icon.paste(art, (offset, offset), art)

    master = ROOT / "app/Resources/icon/Moyo-1024.png"
    icon.save(master)
    print(f"==> {master.relative_to(ROOT)}")

    with tempfile.TemporaryDirectory() as tmp:
        iconset = Path(tmp) / "Moyo.iconset"
        iconset.mkdir()
        for size in ICONSET_SIZES:
            resized = icon.resize((size, size), Image.LANCZOS)
            if size <= 512:
                resized.save(iconset / f"icon_{size}x{size}.png")
            if size >= 32:
                resized.save(iconset / f"icon_{size // 2}x{size // 2}@2x.png")
        out = ROOT / "app/Resources/icon/Moyo.icns"
        subprocess.run(["iconutil", "-c", "icns", str(iconset), "-o", str(out)], check=True)
        print(f"==> {out.relative_to(ROOT)} ({out.stat().st_size // 1024} Ko)")


if __name__ == "__main__":
    main()
