"""Génère des versions WebP (alpha conservé) des illustrations PNG du kit.

Les PNG d'origine restent la source de référence ; les WebP servent uniquement à l'affichage.
Usage : python3 scripts/optimize-illustrations.py
"""
from pathlib import Path
from PIL import Image

SRC = Path(__file__).resolve().parent.parent / "public/assets/noodeu/02_Illustrations_PNG"
OUT = SRC.parent / "02_Illustrations_WEBP"
WIDTH = 720  # 2× la largeur d'affichage maximale (320 px) + marge

OUT.mkdir(exist_ok=True)
for png in sorted(SRC.glob("*.png")):
    im = Image.open(png).convert("RGBA")
    h = round(im.height * WIDTH / im.width)
    im = im.resize((WIDTH, h), Image.LANCZOS)
    dest = OUT / (png.stem + ".webp")
    im.save(dest, "WEBP", quality=82, method=6, exact=True)
    print(f"{png.name}: {png.stat().st_size // 1024} Ko -> {dest.stat().st_size // 1024} Ko")
