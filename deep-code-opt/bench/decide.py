#!/usr/bin/env python3
"""decide.py <result.json> [confirm.json]: aplica regra da skill. Saida: ACEITO/REJEITADO + motivo (1 linha, JSON)."""
import json, sys

def verdict(path):
    r = json.load(open(path)); s = r["summary"]
    if r["dmesg_new_errors"] > 0: return False, "integridade: erros novos no dmesg", s
    gains = [k for k, v in s.items() if v["delta_pct"] <= -0.5 and v["significant"]]
    regs = [k for k, v in s.items() if v["delta_pct"] >= 0.5 and v["significant"]]
    if regs: return False, "regressao significativa em " + ",".join(regs), s
    if not gains: return False, "nenhum ganho >=0.5%% acima de 2xMAD", s
    return True, "ganho significativo em " + ",".join(gains), s
ok, why, s = verdict(sys.argv[1])
if ok and len(sys.argv) > 2:
    ok2, why2, _ = verdict(sys.argv[2])
    if not ok2: ok, why = False, "nao confirmou na re-medicao (" + why2 + ")"
    else: why += " (confirmado)"
print(json.dumps({"accepted": ok, "reason": why, "delta_pct": {k: round(v["delta_pct"], 3) for k, v in s.items()}, "mad2_pct": {k: round(2 * v["mad_comb_pct"], 3) for k, v in s.items()}}))
