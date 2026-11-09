#!/bin/bash
# noise.sh (root): congela fontes de ruido p/ medicao (nao persiste: reboot desfaz tudo).
echo 1 > /sys/devices/system/cpu/intel_pstate/no_turbo
for c in /sys/devices/system/cpu/cpu[0-9]*/cpufreq; do echo performance > $c/scaling_governor 2>/dev/null; done
echo 60 > /sys/devices/system/cpu/intel_pstate/max_perf_pct; echo 60 > /sys/devices/system/cpu/intel_pstate/min_perf_pct
echo 0 > /sys/devices/system/cpu/cpu3/online                       # sibling SMT do P-core 2 ocioso
systemctl stop irqbalance 2>/dev/null
for i in /proc/irq/*/smp_affinity_list; do echo 0-1,4-11 > $i 2>/dev/null; done   # IRQs fora do core 2
pgrep -f cpu_dma_latency_holder >/dev/null || nohup python3 -c "
import os,struct,time,sys; sys.argv[0]='cpu_dma_latency_holder'
f=os.open('/dev/cpu_dma_latency',os.O_WRONLY); os.write(f,struct.pack('i',0)); time.sleep(10**9)" >/dev/null 2>&1 &
echo "noise ok: freq $(cat /sys/devices/system/cpu/cpu2/cpufreq/scaling_cur_freq) kHz"
