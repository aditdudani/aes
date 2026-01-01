import sys
from pathlib import Path


def load_hex(path: str):
    with open(path, 'r') as f:
        return [ln.strip() for ln in f if ln.strip()]


def compare_hex(a_path: str, b_path: str, limit: int | None = None):
    a = load_hex(a_path)
    b = load_hex(b_path)
    if limit is not None:
        a = a[:limit]
        b = b[:limit]
    n = min(len(a), len(b))
    mismatches = []
    for i in range(n):
        if a[i].lower() != b[i].lower():
            mismatches.append(i)
    return {
        "len_a": len(a),
        "len_b": len(b),
        "compared": n,
        "mismatch_count": len(mismatches),
        "first_mismatches": mismatches[:10],
    }


if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: python compare_hex.py <fileA.hex> <fileB.hex> [limit]")
        sys.exit(1)
    a, b = sys.argv[1], sys.argv[2]
    limit = int(sys.argv[3]) if len(sys.argv) > 3 else None
    stats = compare_hex(a, b, limit)
    print(f"A: {a} B: {b}")
    print(f"Compared: {stats['compared']} words")
    print(f"Mismatches: {stats['mismatch_count']}")
    if stats['mismatch_count']:
        print(f"First mismatch indices: {stats['first_mismatches']}")
