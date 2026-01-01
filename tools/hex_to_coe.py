import sys

def hex_to_coe(hex_path: str, coe_path: str):
    with open(hex_path, 'r') as fin:
        lines = [ln.strip() for ln in fin if ln.strip()]
    # Basic validation: each line should be 32 hex chars
    for idx, ln in enumerate(lines):
        if len(ln) != 32 or any(c not in '0123456789abcdefABCDEF' for c in ln):
            raise ValueError(f"Line {idx} is not a 128-bit hex word: '{ln}'")
    with open(coe_path, 'w') as fout:
        fout.write('memory_initialization_radix=16;\n')
        fout.write('memory_initialization_vector=\n')
        for i, ln in enumerate(lines):
            sep = ';' if i == len(lines) - 1 else ','
            fout.write(f"  {ln}{sep}\n")

if __name__ == '__main__':
    if len(sys.argv) != 3:
        print("Usage: python hex_to_coe.py <input.hex> <output.coe>")
        sys.exit(1)
    hex_to_coe(sys.argv[1], sys.argv[2])
