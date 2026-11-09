#!/usr/bin/env python3
"""hypadd.py <id> <meta.json>: registra a hipotese (com decisao medida) em phase4/hypotheses.jsonl via skillgate hyp-add."""
import json, subprocess, sys
h, meta = sys.argv[1], json.load(open(sys.argv[2]))[sys.argv[1]]
d = json.load(open(f"/home/tcfialho/build-optimizations/nvidia-open/bench/results2/{h}_decision.json"))
rec = {"id": h, **meta, "delta_pct": d["composite_mean_delta_pct"], "decision": d["decision"], "reason": d["reason"],
       "per_scenario_delta_pct": {k: v["delta_pct"] for k, v in d["rows"].items()}, "bench_secs": d["bench_secs"], "module_reloads": d["module_reloads"]}
subprocess.run(["python3", "/home/tcfialho/.agents/skillgate/skillgate.py", "hyp-add", json.dumps(rec, ensure_ascii=False)], check=True)
