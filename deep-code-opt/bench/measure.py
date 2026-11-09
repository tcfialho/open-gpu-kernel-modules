#!/usr/bin/env python3
"""ABBA pareado de modulos nvidia. Uso (root): measure.py <nome> <dirA> <dirB> [rounds] [chunks]
Saida: results/<nome>.json com medianas por run e estatistica Mediana±MAD. Integridade: harness rc=0 e zero Xid/NVRM-erro no dmesg."""
import json, os, subprocess, sys, time, statistics as st
HERE = os.path.dirname(os.path.abspath(__file__)); PCORE = "2"
name, dirA, dirB = sys.argv[1:4]
rounds = int(sys.argv[4]) if len(sys.argv) > 4 else 4
chunks = sys.argv[5] if len(sys.argv) > 5 else "200"
SC = ["kcycles", "kinstr", "submit_sync", "event_sync", "dma4k", "dma64k", "malloc_free", "stream_cd", "event_cd", "managed_fault"]
def pkg_temp():
    out = subprocess.run(["sensors"], capture_output=True, text=True).stdout
    for l in out.splitlines():
        if "Package id 0" in l: return float(l.split("+")[1].split("°")[0])
    return 0.0
def dmesg_errs():
    out = subprocess.run(["dmesg"], capture_output=True, text=True).stdout
    return sum(1 for l in out.splitlines() if "Xid" in l or "NVRM: " in l and ("error" in l.lower() or "fail" in l.lower()))
loaded = [None]
def run(label, d):
    while pkg_temp() > 75: time.sleep(4)
    if loaded[0] != d:
        subprocess.run([f"{HERE}/swap.sh", d], check=True); loaded[0] = d
    t0 = time.time()
    r = subprocess.run(["perf", "stat", "-x,", "-e", "cpu_core/cycles/k,cpu_core/instructions/k", "taskset", "-c", PCORE, f"{HERE}/harness", chunks, "500"], capture_output=True, text=True)
    if r.returncode: raise SystemExit(f"harness rc={r.returncode} {r.stderr}")
    j = json.loads(r.stdout); pc = {}
    for l in r.stderr.splitlines():
        f = l.split(",")
        if len(f) > 2 and f[0].isdigit(): pc["kcycles" if "cycles" in f[2] else "kinstr"] = float(f[0])
    if len(pc) != 2: raise SystemExit("perf stat sem contadores: " + r.stderr)
    med = {k: st.median(j[k]) for k in SC if k in j}; med.update(pc)
    return {"label": label, "secs": round(time.time() - t0, 1), "med": med}
subprocess.run("for c in /sys/devices/system/cpu/cpu[0-9]*/cpufreq/scaling_governor; do echo performance > $c; done", shell=True)
errs0 = dmesg_errs(); runs = []
for r in range(rounds):
    order = [("A", dirA), ("B", dirB), ("B", dirB), ("A", dirA)] if r % 2 == 0 else [("B", dirB), ("A", dirA), ("A", dirA), ("B", dirB)]
    for lab, d in order:
        runs.append(run(lab, d)); print(r, lab, runs[-1]["med"], flush=True)
def mad(x): m = st.median(x); return st.median([abs(v - m) for v in x])
summ = {}
for k in SC:
    a = [x["med"][k] for x in runs if x["label"] == "A"]; b = [x["med"][k] for x in runs if x["label"] == "B"]
    ma, mb = st.median(a), st.median(b); mc = (mad(a) ** 2 + mad(b) ** 2) ** 0.5
    summ[k] = {"A": ma, "B": mb, "madA": mad(a), "madB": mad(b), "delta_pct": 100 * (mb - ma) / ma, "mad_comb_pct": 100 * mc / ma,
               "significant": abs(mb - ma) > 2 * mc}
res = {"name": name, "dirA": dirA, "dirB": dirB, "rounds": rounds, "dmesg_new_errors": dmesg_errs() - errs0,
       "bench_secs": round(sum(x["secs"] for x in runs), 1), "summary": summ, "runs": runs}
os.makedirs(f"{HERE}/results", exist_ok=True); json.dump(res, open(f"{HERE}/results/{name}.json", "w"), indent=1)
print(f"{'cenario':12} {'A(us)':>8} {'B(us)':>8} {'delta%':>8} {'2xMAD%':>8} sig"); 
for k, v in summ.items(): print(f"{k:12} {v['A']:8.4f} {v['B']:8.4f} {v['delta_pct']:+8.3f} {2*v['mad_comb_pct']:8.3f} {v['significant']}")
print("dmesg erros novos:", res["dmesg_new_errors"], "| segundos de bench:", res["bench_secs"])
