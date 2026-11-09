#!/bin/bash
# prof_steady.sh <dir_modulos> <saida> (root, janela aberta): 1 recarga, depois perf por cenario com iteracoes suficientes p/ o regime estavel dominar (init CUDA/NVENC < ~15%).
set -e
cd /home/tcfialho/build-optimizations/nvidia-open/bench
MODS=$1; OUT=$2; mkdir -p ../$OUT
./swap.sh ../$MODS > /dev/null
declare -A CH=( [submit_spin]=1500 [fence_block]=600 [alloc2m]=600 [h2d64k]=800 [hostreg1m]=600 [uvm_prefetch2m]=600 [nvenc1080p]=120 )
for s in submit_spin fence_block alloc2m h2d64k hostreg1m uvm_prefetch2m nvenc1080p; do
  SCEN=$s perf record -q -e cpu_core/cycles/k -g -F 6000 -o ../$OUT/$s.data -- taskset -c 2 ./harness2_prof ${CH[$s]} 1.0 > /dev/null 2> ../$OUT/$s.err || echo "perf rc=$? em $s"
done
cat /sys/module/nvidia/sections/.text > ../$OUT/nvidia_text_base.txt
chown -R tcfialho: ../$OUT
echo "PROF_OK $OUT"
