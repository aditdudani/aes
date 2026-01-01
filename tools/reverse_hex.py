import sys

def main(inp, out):
    with open(inp, 'r') as f:
        lines = [ln.strip() for ln in f if ln.strip()]
    lines.reverse()
    with open(out, 'w') as f:
        for ln in lines:
            f.write(ln + "\n")

if __name__ == '__main__':
    if len(sys.argv) != 3:
        print('Usage: python reverse_hex.py <input.hex> <output.hex>')
        sys.exit(1)
    main(sys.argv[1], sys.argv[2])
