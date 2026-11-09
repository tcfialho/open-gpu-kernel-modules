#!/usr/bin/env python3
"""measure2.py <nome> <dir_modulos|-> [--runs R] [--chunks C] [--scale S]  (root, dentro da janela GPU-livre)
dir != '-' => UMA recarga (swap.sh) antes de medir. Mede R execucoes do harness2 em P-core 2.
Saida results2/<nome>.json: por execucao a mediana de cada cenario (wall us/op, kcyc/op)."""
import json, os, subprocess, sys, time, statistics as st, argparse
HERE = os.path.dirname(os.path.abspath(__file__))
ap = argparse.ArgumentParser(); ap.add_argument("name"); ap.add_argument("dir"); ap.add_argument("--runs", type=int, default=12)
ap.add_argument("--chunks", default="20"); ap.add_argument("--scale", default="1.5"); a = ap.parse_args()
def temp():
    for l in subprocess.run(["sensors"], capture_output=True, text=True).stdout.splitlines():
        if "Package id 0" in l: return float(l.split("+")[1].split("°")[0])
    return 0.0
def xid(): return sum(1 for l in subprocess.run(["dmesg"], capture_output=True, text=True).stdout.splitlines() if "Xid" in l or "NVRM: GPU at" in l)
t0 = time.time(); x0 = xid(); reloads = 0
if a.dir != "-":
    subprocess.run([f"{HERE}/swap.sh", a.dir], check=True); reloads = 1
runs = []
for _ in range(a.runs):
    while temp() > 75: time.sleep(3)
    r = subprocess.run(["taskset", "-c", "2", f"{HERE}/harness2", a.chunks, a.scale], capture_output=True, text=True, timeout=55)
    if r.returncode: sys.exit(f"harness2 rc={r.returncode} {r.stderr[-300:]}")
    d = json.loads(r.stdout); runs.append({k: {"wall": st.median(v["wall"]), "kcyc": st.median(v["kcyc"])} for k, v in d.items()})
res = {"name": a.name, "dir": a.dir, "module_reloads": reloads, "bench_secs": round(time.time() - t0, 1), "xid_new": xid() - x0, "runs": runs}
os.makedirs(f"{HERE}/results2", exist_ok=True); json.dump(res, open(f"{HERE}/results2/{a.name}.json", "w"), indent=1)
print(json.dumps({"name": a.name, "bench_secs": res["bench_secs"], "xid_new": res["xid_new"]}))
