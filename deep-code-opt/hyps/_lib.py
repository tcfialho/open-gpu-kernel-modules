import pathlib, sys
ROOT = pathlib.Path("/home/tcfialho/build-optimizations/nvidia-open/src")
def patch(rel, pairs):
    p = ROOT / rel; s = p.read_text()
    for a, b in pairs:
        if s.count(a) != 1: sys.exit(f"ANCORA NAO UNICA/AUSENTE em {rel}: {a[:80]!r} (n={s.count(a)})")
        s = s.replace(a, b)
    p.write_text(s); print("aplicado", rel)
