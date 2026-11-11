"""Builds the UI icon PNGs in this folder from Codex's Style A originals.

Each original is trimmed to its artwork (alpha >= 48, which ignores the faint glow edge), then centred on a
transparent 512 x 512 canvas with its longer side at FILL of the canvas. Every icon then has the same
visual size and sits dead centre, whatever the generator left around it.

Usage: python normalize.py <folder with icon-*.png and pet-*.png>
"""
import sys
from pathlib import Path

from PIL import Image

SIZE = 512
FILL = 0.9
ALPHA_CUT = 48
# Originals named differently from their Templates.Icons ImageLabel.
RENAME = {"pet-clownfish": "Fish", "pet-golden-krill": "Shrimp", "pet-jellyfish": "Jelly"}


def icon_name(stem: str) -> str:
    if stem in RENAME:
        return RENAME[stem]
    return stem.split("-", 1)[1].replace("-", " ").title().replace(" ", "")


def normalize(src: Path, dest: Path) -> None:
    image = Image.open(src).convert("RGBA")
    box = image.getchannel("A").point(lambda v: 255 if v >= ALPHA_CUT else 0).getbbox()
    art = image.crop(box)
    scale = SIZE * FILL / max(art.size)
    art = art.resize((round(art.width * scale), round(art.height * scale)), Image.LANCZOS)
    canvas = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    canvas.alpha_composite(art, ((SIZE - art.width) // 2, (SIZE - art.height) // 2))
    canvas.save(dest, optimize=True)


def main() -> None:
    source = Path(sys.argv[1])
    out = Path(__file__).parent
    for src in sorted(source.glob("*.png")):
        if not src.stem.startswith(("icon-", "pet-")) or src.stem == "icon-set-preview":
            continue
        normalize(src, out / f"{icon_name(src.stem)}.png")
        print(src.name, "->", f"{icon_name(src.stem)}.png")


if __name__ == "__main__":
    main()
