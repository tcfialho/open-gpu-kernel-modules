import json, statistics as st
SENS = ["fence_block", "uvm_prefetch2m", "alloc2m", "hostreg1m", "ctx_create", "nvenc1080p"]
MET = {"fence_block": "wall", "uvm_prefetch2m": "kcyc", "alloc2m": "kcyc", "hostreg1m": "kcyc", "ctx_create": "wall", "nvenc1080p": "wall"}
def med(n, sc): return st.median(r[sc][MET[sc]] for r in json.load(open(f"results2/{n}.json"))["runs"])
champs = ["final_R4H2", "abl_c2", "abl_c3", "abl_c4", "abl_c5", "abl_c6"]
out = {"champ_loads": {}, "abl": {}}
print("== campeao em 6 cargas (variancia entre cargas)")
base = {}
for sc in SENS:
    v = [med(c, sc) for c in champs]; m = st.mean(v); base[sc] = m
    sp = 100 * (max(v) - min(v)) / m; sd = 100 * st.pstdev(v) / m
    out["champ_loads"][sc] = {"mean": m, "spread_pct": round(sp, 3), "sd_pct": round(sd, 3)}
    print(f"{sc:15} media {m:12.2f}  spread {sp:5.2f}%  sd {sd:5.2f}%")
print("\n== efeito de REMOVER cada mudanca (+ = campeao melhor com ela; delta = (sem - campeao)/campeao)")
names = ["R1H1", "R2H2", "R2H3", "R3H1", "R3H4", "R4H2", "R4H1", "ISRGATE"]
print(f"{'sem':8}" + "".join(f"{s[:9]:>12}" for s in SENS))
for n in names:
    row = {}; line = f"{n:8}"
    for sc in SENS:
        d = 100 * (med(f"abl_{n}", sc) - base[sc]) / base[sc]; row[sc] = round(d, 3)
        flag = "*" if abs(d) > max(1.0, 2 * out["champ_loads"][sc]["sd_pct"]) else " "
        line += f"{d:+11.2f}{flag}"
    out["abl"][n] = row; print(line)
json.dump(out, open("results2/ablation_summary.json", "w"), indent=1)
print("\n* = |efeito| > max(1%, 2x desvio entre cargas do campeao)")
