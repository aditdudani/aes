import sys
from pathlib import Path

def parse_coe_lines(coe_path: Path) -> list[str]:
    words = []
    with coe_path.open('r') as f:
        in_vec = False
        for raw in f:
            line = raw.strip()
            if not line:
                continue
            if line.startswith('memory_initialization_vector'):
                in_vec = True
                continue
            if not in_vec:
                continue
            # strip trailing comma/semicolon
            line = line.rstrip(',;').strip()
            if not line:
                continue
            # remove spaces
            word = line.replace(' ', '')
            # validate hex characters
            try:
                int(word, 16)
            except ValueError:
                raise ValueError(f'Invalid hex word: {line}')
            words.append(word)
    return words


def write_hex(hex_path: Path, words: list[str]):
    with hex_path.open('w') as f:
        for w in words:
            f.write(f"{w}\n")


def main():
    if len(sys.argv) != 3:
        print('Usage: python coe_to_hex.py input.coe output.hex')
        sys.exit(1)
    inp = Path(sys.argv[1])
    out = Path(sys.argv[2])
    words = parse_coe_lines(inp)
    write_hex(out, words)
    print(f'Wrote HEX: {out} ({len(words)} words)')

if __name__ == '__main__':
    main()
