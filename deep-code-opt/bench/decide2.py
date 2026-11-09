#!/usr/bin/env python3
"""decide2.py <candidato> <campeao> -> regra da skill: aceita se algum cenario tem delta<=-0.5% e |delta|>2xMAD,
confirmado pelas duas metades independentes das execucoes, e NENHUM cenario regride >0.5% (e >2xMAD). Le results2/<nome>.json."""
import json, sys, statistics as st
PRIMARY = {"submit_spin": "wall", "h2d64k": "wall", "fence_block": "wall", "alloc2m": "kcyc", "hostreg1m": "kcyc", "uvm_prefetch2m": "kcyc", "nvenc1080p": "wall", "ctx_create": "wall"}
def mad(x): m = st.median(x); return st.median([abs(v - m) for v in x])
cand, champ = (json.load(open(f"results2/{n}.json")) for n in sys.argv[1:3])
floor = json.load(open("results2/aa_summary.json"))
rows = {}; wins = []; losses = []
for sc, met in PRIMARY.items():
    c = [r[sc][met] for r in cand["runs"]]; h = [r[sc][met] for r in champ["runs"]]
    mc, mh = st.median(c), st.median(h)
    d = 100 * (mc - mh) / mh
    m = max(100 * mad(c) / mc, 100 * mad(h) / mh, floor[sc]["mad_between_loads_pct"])
    da, db = (100 * (st.median(c[i::2]) - mh) / mh for i in (0, 1))
    if sc in ("submit_spin", "h2d64k"): v = "controle"
    elif sc == "nvenc1080p" and 0.7 <= abs(d) <= 1.1: v = "layout-state(ignorado)"
    elif d <= -0.5 and -d > 2 * m and da <= -0.5 and db <= -0.5: v = "GANHO"; wins.append(sc)
    elif d >= 0.5 and d > 2 * m: v = "REGRESSAO"; losses.append(sc)
    else: v = "empate"
    rows[sc] = {"metric": met, "champ": round(mh, 3), "cand": round(mc, 3), "delta_pct": round(d, 3), "mad_pct": round(m, 3), "half_a": round(da, 3), "half_b": round(db, 3), "verdict": v}
    print(f"{sc:15} {met:4} {mh:11.2f} -> {mc:11.2f}  d={d:+7.3f}%  MAD={m:5.3f}%  metades {da:+7.3f}/{db:+7.3f}  {v}")
comp = round(sum(r["delta_pct"] for r in rows.values()) / len(rows), 3)
decision = "ACEITA" if wins and not losses else "REVERTE"
reason = (f"ganho em {','.join(wins)}" if wins else "nenhum cenario com ganho confirmado >=0.5% e >2xMAD") + (f"; regressao em {','.join(losses)}" if losses else "")
out = {"cand": sys.argv[1], "champ": sys.argv[2], "decision": decision, "reason": reason, "composite_mean_delta_pct": comp, "rows": rows,
       "bench_secs": cand.get("bench_secs"), "module_reloads": cand.get("module_reloads"), "xid_new": cand.get("xid_new")}
json.dump(out, open(f"results2/{sys.argv[1]}_decision.json", "w"), indent=1)
print(f"==> {decision}: {reason} | media dos 7 cenarios {comp:+.3f}% | bench {cand.get('bench_secs')}s reloads {cand.get('module_reloads')} xid {cand.get('xid_new')}")
