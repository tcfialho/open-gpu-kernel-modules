#!/bin/bash
# prof_loop.sh <saida> (root, modulos ja carregados): perf SO dentro do laco medido de cada cenario (init excluido).
cd /home/tcfialho/build-optimizations/nvidia-open/bench; OUT=../$1; mkdir -p $OUT
declare -A CH=( [submit_spin]=40 [fence_block]=40 [alloc2m]=40 [h2d64k]=40 [hostreg1m]=40 [uvm_prefetch2m]=40 [nvenc1080p]=40 [ctx_create]=40 )
for s in fence_block uvm_prefetch2m ctx_create; do
  rm -f /tmp/pc.ctl /tmp/pc.ack; mkfifo /tmp/pc.ctl /tmp/pc.ack; exec {c}<>/tmp/pc.ctl; exec {a}<>/tmp/pc.ack
  SCEN=$s CTLFD=$c ACKFD=$a perf record -q -e cpu_core/cycles/k -g -F 12000 -D -1 --control fd:$c,$a -o $OUT/$s.data -- taskset -c 2 ./harness2_prof ${CH[$s]} 1.2 > /dev/null 2> $OUT/$s.err || echo "rc=$? $s"
  exec {c}>&- {a}>&-
done
cat /sys/module/nvidia/sections/.text > $OUT/nvidia_text_base.txt; chown -R tcfialho: $OUT; echo PROFLOOP_OK
