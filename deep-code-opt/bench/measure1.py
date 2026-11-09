#!/usr/bin/env python3
"""measure1.py <nome> <dir_modulos> [--ref ref.json] [--loads N] [--runs R]: UMA carga do modulo por load, R runs do harness. Root."""
import json, os, subprocess, sys, time, statistics as st, argparse
HERE = os.path.dirname(os.path.abspath(__file__)); PCORE = "2"
ap = argparse.ArgumentParser(); ap.add_argument("name"); ap.add_argument("dir"); ap.add_argument("--ref"); ap.add_argument("--loads", type=int, default=1); ap.add_argument("--runs", type=int, default=12); ap.add_argument("--chunks", default="80")
a = ap.parse_args()
SC = ["kcycles", "kinstr", "submit_sync", "event_sync", "dma4k", "dma64k", "malloc_free", "stream_cd", "event_cd", "managed_fault"]
def pkg_temp():
    for l in subprocess.run(["sensors"], capture_output=True, text=True).stdout.splitlines():
        if "Package id 0" in l: return float(l.split("+")[1].split("°")[0])
    return 0.0
def dmesg_errs():
    return sum(1 for l in subprocess.run(["dmesg"], capture_output=True, text=True).stdout.splitlines() if "Xid" in l)
def one():
    r = subprocess.run(["perf", "stat", "-x,", "-e", "cpu_core/cycles/k,cpu_core/instructions/k", "taskset", "-c", PCORE, f"{HERE}/harness", a.chunks, "500"], capture_output=True, text=True)
    if r.returncode: raise SystemExit(f"harness rc={r.returncode} {r.stderr}")
    j = json.loads(r.stdout); med = {k: st.median(j[k]) for k in SC if k in j}
    for l in r.stderr.splitlines():
        f = l.split(",")
        if len(f) > 2 and f[0].isdigit(): med["kcycles" if "cycles" in f[2] else "kinstr"] = float(f[0])
    return med
subprocess.run("for c in /sys/devices/system/cpu/cpu[0-9]*/cpufreq/scaling_governor; do echo performance > $c; done", shell=True)
e0 = dmesg_errs(); runs = []; t0 = time.time()
for _ in range(a.loads):
    while pkg_temp() > 75: time.sleep(4)
    subprocess.run([f"{HERE}/swap.sh", a.dir], check=True)
    for _ in range(a.runs): runs.append(one())
def mad(x): m = st.median(x); return st.median([abs(v - m) for v in x])
res = {"name": a.name, "dir": a.dir, "loads": a.loads, "runs": runs, "dmesg_new_errors": dmesg_errs() - e0, "bench_secs": round(time.time() - t0, 1)}
summ = {}
if a.ref:
    ref = json.load(open(a.ref))["runs"]
    for k in SC:
        A = [r[k] for r in ref]; B = [r[k] for r in runs]; ma, mb = st.median(A), st.median(B); mc = (mad(A) ** 2 + mad(B) ** 2) ** 0.5
        summ[k] = {"A": ma, "B": mb, "delta_pct": 100 * (mb - ma) / ma, "mad_comb_pct": 100 * mc / ma, "significant": abs(mb - ma) > 2 * mc}
    res["summary"] = summ
os.makedirs(f"{HERE}/results", exist_ok=True); json.dump(res, open(f"{HERE}/results/{a.name}.json", "w"), indent=1)
print(a.name, "segundos:", res["bench_secs"], "dmesg:", res["dmesg_new_errors"])
for k, v in summ.items(): print(f"{k:14}{v['A']:12.4f}{v['B']:12.4f}{v['delta_pct']:+8.3f}% 2xMAD={2*v['mad_comb_pct']:.3f}% sig={v['significant']}")
