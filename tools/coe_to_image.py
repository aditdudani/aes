import sys
from pathlib import Path

"""
Simple COE -> image converter.
- Reads a Xilinx COE with 128-bit hex words.
- Writes a grayscale PGM (Portable GrayMap) image from the byte stream.

Usage:
  python coe_to_image.py input.coe output.pgm width height

Notes:
- PGM is easy to view with most image tools and requires no dependencies.
- If the byte count doesn't match width*height, trailing bytes are ignored.
"""

def parse_coe(coe_path: Path) -> bytes:
    data_bytes = bytearray()
    with coe_path.open('r') as f:
        in_vec = False
        for line in f:
            line = line.strip()
            if not line:
                continue
            if line.startswith('memory_initialization_vector'):
                in_vec = True
                continue
            if not in_vec:
                continue
            if line.endswith(';'):
                line = line[:-1]
                # last line
                pass
            # Remove trailing commas
            line = line.rstrip(',')
            if not line:
                continue
            # 128-bit word per line (32 hex chars). Convert to 16 bytes, big-endian.
            word_hex = line
            # Allow spaces
            word_hex = word_hex.replace(' ', '')
            # Validate length multiple of 2
            if len(word_hex) % 2 != 0:
                raise ValueError(f"Invalid hex length: {len(word_hex)} for line: {line}")
            # Convert hex to bytes
            try:
                word_bytes = bytes.fromhex(word_hex)
            except ValueError as e:
                raise ValueError(f"Invalid hex in line: {line}") from e
            data_bytes.extend(word_bytes)
    return bytes(data_bytes)


def write_pgm(output_path: Path, pixel_bytes: bytes, width: int, height: int):
    # If extra bytes, truncate; if too few, pad with zeros
    expected = width * height
    buf = bytearray(pixel_bytes[:expected])
    if len(buf) < expected:
        buf.extend(b"\x00" * (expected - len(buf)))
    with output_path.open('wb') as out:
        out.write(f"P5\n{width} {height}\n255\n".encode('ascii'))
        out.write(buf)


def main():
    if len(sys.argv) != 5:
        print("Usage: python coe_to_image.py input.coe output.pgm width height")
        sys.exit(1)
    coe_path = Path(sys.argv[1])
    out_path = Path(sys.argv[2])
    width = int(sys.argv[3])
    height = int(sys.argv[4])
    pixel_bytes = parse_coe(coe_path)
    write_pgm(out_path, pixel_bytes, width, height)
    print(f"Wrote PGM image: {out_path}")

if __name__ == '__main__':
    main()
