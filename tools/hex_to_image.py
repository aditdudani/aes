import sys
from pathlib import Path

def hex_to_image(hex_path: str, width: int, height: int, pgm_path: str):
    with open(hex_path, 'r') as fin:
        words = [ln.strip() for ln in fin if ln.strip()]
    # Concatenate into bytes
    data = bytearray()
    for ln in words:
        if len(ln) != 32 or any(c not in '0123456789abcdefABCDEF' for c in ln):
            raise ValueError(f"Invalid 128-bit word: {ln}")
        data.extend(bytes.fromhex(ln))
    # Truncate or pad to requested size
    expected = width * height
    if len(data) < expected:
        data.extend(b'\x00' * (expected - len(data)))
    elif len(data) > expected:
        data = data[:expected]
    # Write PGM (P5)
    with open(pgm_path, 'wb') as f:
        f.write(f"P5\n{width} {height}\n255\n".encode())
        f.write(data)

if __name__ == '__main__':
    if len(sys.argv) != 5:
        print("Usage: python hex_to_image.py <input.hex> <width> <height> <output.pgm>")
        sys.exit(1)
    hex_to_image(sys.argv[1], int(sys.argv[2]), int(sys.argv[3]), sys.argv[4])
