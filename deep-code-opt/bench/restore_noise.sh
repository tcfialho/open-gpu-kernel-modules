#!/bin/bash
# restore_noise.sh (root): desfaz o noise.sh (turbo, limites de pstate, cpu3, irqbalance, dma latency, clock da GPU). Governor nao mudou (gaming-performance ja usa performance).
P=/sys/devices/system/cpu
echo 0 > $P/intel_pstate/no_turbo
mn=$(cat $P/cpu2/cpufreq/cpuinfo_min_freq); mx=$(cat $P/cpu2/cpufreq/cpuinfo_max_freq)
echo 100 > $P/intel_pstate/max_perf_pct; echo $(( (100*mn + mx - 1) / mx )) > $P/intel_pstate/min_perf_pct
echo 1 > $P/cpu3/online
for p in $(pgrep -f cpu_dma_latency_holder); do
  if tr '\0' ' ' < /proc/$p/cmdline | grep -q '^python3 -c' && grep -q cpu_dma_latency /proc/$p/cmdline; then kill $p && echo "holder $p encerrado"; fi
done
systemctl is-enabled irqbalance >/dev/null 2>&1 && systemctl start irqbalance && echo "irqbalance reativado"
nvidia-smi -rgc >/dev/null 2>&1 && echo "clock da GPU destravado"
echo "no_turbo=$(cat $P/intel_pstate/no_turbo) max=$(cat $P/intel_pstate/max_perf_pct) min=$(cat $P/intel_pstate/min_perf_pct) cpu3=$(cat $P/cpu3/online) irqbalance=$(systemctl is-active irqbalance)"
nvidia-smi --query-gpu=clocks.gr,clocks.max.gr --format=csv,noheader
