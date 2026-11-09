import subprocess, bisect, sys, re
d, ko, uvm = sys.argv[1], sys.argv[2], sys.argv[3]
base = int(open(f"{d}/nvidia_text_base.txt").read().strip(), 16)
def load(path):
    out = subprocess.run(["nm", "-n", path], capture_output=True, text=True).stdout.splitlines()
    s = [(int(l.split()[0], 16), l.split()[2]) for l in out if len(l.split()) == 3 and l.split()[1] in "tTwW"]
    return [x[0] for x in s], s
NV = load(ko); UV = load(uvm)
def sym(tab, a):
    A, S = tab; i = bisect.bisect_right(A, a) - 1; return f"{S[i][1]}+{a - S[i][0]:#x}" if i >= 0 else hex(a)
def fix(line):
    m = re.search(r"\[(nvidia|nvidia_uvm)\]\s+\[k\] (0x[0-9a-f]+)", line)
    if m: return line.replace(m.group(2), sym(NV if m.group(1) == "nvidia" else UV, int(m.group(2), 16)))
    return re.sub(r"0xffffffffc[0-9a-f]{7}", lambda mm: (sym(NV, int(mm.group(0), 16) - base) if 0 <= int(mm.group(0), 16) - base < 0x400000 else mm.group(0)), line)
for scen in sys.argv[4:]:
    print(f"=== {scen}")
    t = subprocess.run(["perf", "report", "-i", f"{d}/{scen}.data", "--no-children", "--sort", "dso,sym", "--stdio", "-q", "-g", "none", "--percent-limit", "1.5"], capture_output=True, text=True).stdout
    for l in t.splitlines()[:9]:
        if "%" in l: print(" ", fix(l)[:118])
