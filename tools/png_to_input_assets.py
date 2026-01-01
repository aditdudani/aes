import sys
from pathlib import Path

"""
png_to_input_assets.py

Convert a source PNG image to the trio of files the AES pipeline expects:
  - Grayscale PGM (P5) -> input_second.pgm
  - COE memory file    -> input_second.coe
  - HEX words file     -> input_second.hex

Usage:
  python png_to_input_assets.py input.png [size] [output_prefix]

Arguments:
  input.png      : Source image (PNG). Will be converted to 8-bit grayscale.
  size           : Optional single integer (e.g. 512) to enforce square resize.
                   If omitted and image is already square, original size used.
  output_prefix  : Optional prefix (default: input_second). Files created:
                   <prefix>.pgm, <prefix>.coe, <prefix>.hex

Requires Pillow. Install if missing:
  python -m pip install pillow
"""

try:
    from PIL import Image
except ImportError:
    print("ERROR: Pillow not installed. Install with: pip install pillow")
    sys.exit(1)


def image_to_grayscale_bytes(png_path: Path, target_size: int | None) -> tuple[bytes, int, int]:
    img = Image.open(png_path).convert("L")  # grayscale
    w, h = img.size
    if target_size is not None:
        img = img.resize((target_size, target_size), Image.LANCZOS)
        w = h = target_size
    elif w != h:
        # Enforce square if not resizing; user must supply size
        raise ValueError(f"Image is not square ({w}x{h}). Provide a size argument to resize.")
    data = img.tobytes()
    return data, w, h


def write_pgm(pgm_path: Path, data: bytes, w: int, h: int):
    with pgm_path.open('wb') as f:
        f.write(f"P5\n{w} {h}\n255\n".encode())
        f.write(data)


def bytes_to_words_hex(data: bytes) -> list[str]:
    words = []
    for i in range(0, len(data), 16):
        chunk = data[i:i+16]
        if len(chunk) < 16:
            chunk = chunk + b"\x00" * (16 - len(chunk))
        words.append(chunk.hex())
    return words


def write_coe(coe_path: Path, words_hex: list[str]):
    with coe_path.open('w') as f:
        f.write('memory_initialization_radix=16;\n')
        f.write('memory_initialization_vector=\n')
        for i, w in enumerate(words_hex):
            sep = ';' if i == len(words_hex) - 1 else ','
            f.write(f'  {w}{sep}\n')


def write_hex(hex_path: Path, words_hex: list[str]):
    with hex_path.open('w') as f:
        for w in words_hex:
            f.write(f"{w}\n")


def main():
    if len(sys.argv) < 2:
        print("Usage: python png_to_input_assets.py input.png [size] [output_prefix]")
        sys.exit(1)
    png_file = Path(sys.argv[1])
    target_size = None
    prefix = "data/input_second"
    if len(sys.argv) >= 3:
        try:
            target_size = int(sys.argv[2])
        except ValueError:
            # If second arg isn't int, treat as prefix
            prefix = sys.argv[2]
            target_size = None
    if len(sys.argv) == 4:
        prefix = sys.argv[3]

    data, w, h = image_to_grayscale_bytes(png_file, target_size)
    words = bytes_to_words_hex(data)

    pgm_path = Path(f"{prefix}.pgm")
    coe_path = Path(f"{prefix}.coe")
    hex_path = Path(f"{prefix}.hex")

    write_pgm(pgm_path, data, w, h)
    write_coe(coe_path, words)
    write_hex(hex_path, words)

    print(f"Generated: {pgm_path}, {coe_path}, {hex_path} ({len(words)} words, {w}x{h})")


if __name__ == '__main__':
    main()
