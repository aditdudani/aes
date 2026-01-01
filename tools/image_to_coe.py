import sys
from pathlib import Path

"""
Simple image (PGM) -> COE converter.
- Reads a grayscale PGM (Portable GrayMap) file.
- Emits a COE file with 128-bit words (16 bytes per word) from pixel bytes.

Usage:
  python image_to_coe.py input.pgm output.coe

This script expects binary PGM (P5).
"""

def read_pgm(path: Path) -> bytes:
    with path.open('rb') as f:
        header = f.readline().strip()
        if header != b'P5':
            raise ValueError('Only binary PGM (P5) supported')
        # Skip comments
        def read_non_comment():
            line = f.readline()
            while line.startswith(b'#'):
                line = f.readline()
            return line
        dims = read_non_comment().strip()
        width, height = map(int, dims.split())
        maxval = int(read_non_comment().strip())
        if maxval > 255:
            raise ValueError('Only 8-bit PGM supported')
        pixel_data = f.read(width * height)
        return pixel_data


def bytes_to_words_hex(data: bytes) -> list[str]:
    words = []
    for i in range(0, len(data), 16):
        chunk = data[i:i+16]
        if len(chunk) < 16:
            chunk = chunk + b"\x00" * (16 - len(chunk))
        words.append(chunk.hex())
    return words


def write_coe(path: Path, words_hex: list[str]):
    with path.open('w') as f:
        f.write('memory_initialization_radix=16;\n')
        f.write('memory_initialization_vector=\n')
        for i, w in enumerate(words_hex):
            if i == len(words_hex) - 1:
                f.write(f'  {w};\n')
            else:
                f.write(f'  {w},\n')


def main():
    if len(sys.argv) != 3:
        print('Usage: python image_to_coe.py input.pgm output.coe')
        sys.exit(1)
    inp = Path(sys.argv[1])
    out = Path(sys.argv[2])
    pixels = read_pgm(inp)
    words = bytes_to_words_hex(pixels)
    write_coe(out, words)
    print(f'Wrote COE: {out}')

if __name__ == '__main__':
    main()
