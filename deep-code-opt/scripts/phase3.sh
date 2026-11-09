#!/bin/bash
# phase3.sh (root, janela JA aberta e ruido aplicado): mede o BASE (1 recarga, <=60 s) contra o As-Is (ref_asis) e grava os artefatos da Fase 3.
cd /home/tcfialho/build-optimizations/nvidia-open || exit 1
P3=$(sudo -u tcfialho python3 /home/tcfialho/.agents/skillgate/skillgate.py path phase3 | tail -1)
python3 bench/measure2.py base_vs_asis mods/base --runs 8 --chunks 40 --scale 1.2 || exit 2
chown -R tcfialho: bench/results2
cd bench
sudo -u tcfialho python3 decide2.py base_vs_asis ref_asis | tee /tmp/phase3_decide.txt
sudo -u tcfialho python3 - "$P3" <<'PY'
import json, sys
p3 = sys.argv[1]; d = json.load(open("results2/base_vs_asis_decision.json")); m = json.load(open("results2/base_vs_asis.json"))
out = {"bench_secs": m["bench_secs"], "module_reloads": m["module_reloads"], "xid_new": m["xid_new"], "champ": "asis (ref_asis, 24 runs / 3 cargas)", "cand": "base (-O3 -mtune=native -flto=thin ...)",
       "composite_mean_delta_pct": d["composite_mean_delta_pct"], "rows": d["rows"]}
json.dump(out, open(f"{p3}/base_vs_asis.json", "w"), indent=1)
md = ["# Fase 3 - Base (flags aprovadas) vs As-Is (driver do sistema)", "",
      f"Bateria: {m['bench_secs']} s, {m['module_reloads']} recarga de modulo, Xid novos: {m['xid_new']}. Delta negativo = base mais rapido.", "",
      "| cenario | metrica | As-Is | Base | delta % | MAD % | metade A / B | veredito |", "|---|---|---|---|---|---|---|---|"]
for k, r in d["rows"].items():
    md.append(f"| {k} | {r['metric']} | {r['champ']} | {r['cand']} | {r['delta_pct']:+.3f} | {r['mad_pct']:.3f} | {r['half_a']:+.3f} / {r['half_b']:+.3f} | {r['verdict']} |")
md += ["", f"Media dos 7 cenarios: {d['composite_mean_delta_pct']:+.3f}%. Decisao da regra: {d['decision']} ({d['reason']}).",
       "O base (so flags de compilador) nao e hipotese: e o ponto de partida (campeao) das 25 hipoteses de codigo da Fase 4."]
open(f"{p3}/base_vs_asis.md", "w").write("\n".join(md) + "\n")
print("artefatos fase 3 escritos em", p3)
PY
