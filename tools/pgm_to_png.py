import sys
from pathlib import Path

def pgm_to_png(pgm_path: str, png_path: str):
    try:
        from PIL import Image
    except ImportError:
        print("ERROR: Pillow (PIL) not installed. Install with: pip install pillow")
        sys.exit(1)
    img = Image.open(pgm_path).convert("L")
    img.save(png_path)
    print(f"Wrote PNG: {png_path}")

if __name__ == '__main__':
    if len(sys.argv) != 3:
        print("Usage: python pgm_to_png.py <input.pgm> <output.png>")
        sys.exit(1)
    pgm_to_png(sys.argv[1], sys.argv[2])
