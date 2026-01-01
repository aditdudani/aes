import sys

HEXCHARS = set("0123456789abcdefABCDEF")

def sanitize(inp, out):
    with open(inp, 'r') as f:
        lines = [ln.rstrip("\r\n") for ln in f]
    clean = []
    for ln in lines:
        s = ln.strip()
        if len(s) == 32 and all(c in HEXCHARS for c in s):
            clean.append(s)
        else:
            # replace invalid word with zeros (preserve count)
            if s:
                clean.append("0" * 32)
    with open(out, 'w') as f:
        for ln in clean:
            f.write(ln + "\n")

if __name__ == '__main__':
    if len(sys.argv) != 3:
        print('Usage: python sanitize_hex.py <input.hex> <output.hex>')
        sys.exit(1)
    sanitize(sys.argv[1], sys.argv[2])
