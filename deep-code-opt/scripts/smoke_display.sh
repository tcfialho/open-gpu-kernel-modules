#!/bin/bash
# smoke_display.sh (root): com os modulos FINAL carregados em MEMORIA (nao instalados), sobe o sddm/River e testa vblank/page-flip (vkcube, glxgears) + dmesg.
LOG=/home/tcfialho/build-optimizations/nvidia-open/state_smoke.log; exec > >(tee -a $LOG) 2>&1
echo "== $(date +%T) smoke display"
loaded=$(modinfo -F srcversion /home/tcfialho/build-optimizations/nvidia-open/mods/FINAL/nvidia.ko); cur=$(cat /sys/module/nvidia/srcversion 2>/dev/null)
echo "srcversion FINAL=$loaded carregado=$cur"; [ "$loaded" = "$cur" ] || { echo "SMOKE_ABORT modulos carregados nao sao o FINAL"; exit 2; }
dm0=$(dmesg | grep -ciE "Xid|NVRM: GPU at|timeout|nobody cared|BUG:|Oops|WARNING: CPU")
i0=$(grep -i nvidia /proc/interrupts | awk '{for(i=2;i<=NF;i++) if($i ~ /^[0-9]+$/) s+=$i} END{print s+0}')
systemctl start sddm; echo "sddm iniciado"
for t in $(seq 1 60); do pgrep -x river >/dev/null && break; sleep 1; done
pgrep -x river >/dev/null && echo "river vivo apos ${t}s" || { echo "SMOKE_FAIL river nao subiu"; exit 3; }
sleep 8
WS=$(ls /run/user/1000/ | grep -E '^wayland-[0-9]+$' | head -1); echo "wayland socket: ${WS:-nenhum}"
run() { sudo -u tcfialho env XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=$WS "$@"; }
t0=$(date +%s.%N); timeout 40 sudo -u tcfialho env XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=$WS vkcube --c 600 >/tmp/vkcube.out 2>&1; rc=$?; t1=$(date +%s.%N)
echo "vkcube 600 frames rc=$rc tempo=$(echo "$t1 - $t0" | bc) s (esperado ~5 s a 120 Hz); $(tail -1 /tmp/vkcube.out | cut -c1-120)"
timeout 12 sudo -u tcfialho env XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=$WS glxgears > /tmp/glx.out 2>&1; echo "glxgears: $(grep -E 'frames in' /tmp/glx.out | tail -2 | tr '\n' ' ' | cut -c1-160)"
dm1=$(dmesg | grep -ciE "Xid|NVRM: GPU at|timeout|nobody cared|BUG:|Oops|WARNING: CPU")
i1=$(grep -i nvidia /proc/interrupts | awk '{for(i=2;i<=NF;i++) if($i ~ /^[0-9]+$/) s+=$i} END{print s+0}')
echo "IRQs nvidia durante o teste: $((i1-i0)); erros novos no dmesg: $((dm1-dm0))"
dmesg | tail -5 | cut -c1-160
pgrep -x river >/dev/null && echo "river ainda vivo" ; echo SMOKE_DONE
