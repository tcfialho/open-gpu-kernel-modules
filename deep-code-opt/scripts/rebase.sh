#!/bin/bash
# rebase.sh (root, janela aberta): rebaseline com o harness novo (ctx_create): as-is x2 cargas + base x1.
cd /home/tcfialho/build-optimizations/nvidia-open/bench
python3 measure2.py asis2_load1 ../mods/asis --runs 6 --chunks 40 --scale 1.2 || exit 2
python3 measure2.py asis2_load2 ../mods/asis --runs 6 --chunks 40 --scale 1.2 || exit 2
python3 measure2.py base2 ../mods/base --runs 6 --chunks 40 --scale 1.2 || exit 2
chown -R tcfialho: results2
sudo -u tcfialho python3 - <<'PY'
import json
a, b = (json.load(open(f"results2/asis2_load{i}.json")) for i in (1, 2))
json.dump({"name": "ref_asis2", "runs": a["runs"] + b["runs"], "bench_secs": a["bench_secs"], "module_reloads": 1}, open("results2/ref_asis2.json", "w"))
PY
sudo -u tcfialho python3 aastat.py results2/asis2_load1.json results2/asis2_load2.json 2>&1 | tail -9
echo REBASE_OK
