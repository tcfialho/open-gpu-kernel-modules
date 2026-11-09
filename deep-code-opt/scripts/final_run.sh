#!/bin/bash
# final_run.sh (root, janela aberta): A/B/A/B intercalado asis x FINAL (1 recarga por medicao) + IRQs por fence (condicoes 1,3,4 do Judge).
cd /home/tcfialho/build-optimizations/nvidia-open/bench
M() { python3 measure2.py "$1" "../mods/$2" --runs 6 --chunks 40 --scale 1.2 | tail -1; }
IRQ() {  # $1 rotulo; modulo ja carregado
  python3 - "$1" <<'PY'
import re, subprocess, sys, json, os
def irqs():
    tot = 0
    for l in open("/proc/interrupts"):
        if "nvidia" in l.lower():
            tot += sum(int(x) for x in l.split(":", 1)[1].split() if x.isdigit())
    return tot
def xid():
    t = subprocess.run(["dmesg"], capture_output=True, text=True).stdout.splitlines()
    return sum(1 for l in t if re.search(r"Xid|NVRM: GPU at|timeout|Timeout|nobody cared|BUG:|Oops", l))
i0, x0 = irqs(), xid()
env = dict(os.environ, SCEN="fence_block")
r = subprocess.run(["taskset", "-c", "2", "./harness2_prof", "40", "1.2"], capture_output=True, text=True, env=env)
d = json.loads(r.stdout); ops = 40 * int(200 * 1.2) + int(200 * 1.2)
i1, x1 = irqs(), xid()
print(json.dumps({"label": sys.argv[1], "ops": ops, "irqs": i1 - i0, "irqs_per_fence": round((i1 - i0) / ops, 3), "dmesg_novos_erros": x1 - x0}))
PY
}
M asisF1 asis;   IRQ asis_1  | tee -a ../results2_irq.jsonl
M FINAL1 FINAL;  IRQ FINAL_1 | tee -a ../results2_irq.jsonl
M asisF2 asis;   IRQ asis_2  | tee -a ../results2_irq.jsonl
M FINAL2 FINAL;  IRQ FINAL_2 | tee -a ../results2_irq.jsonl
chown -R tcfialho: results2 ../results2_irq.jsonl
echo FINALRUN_OK
