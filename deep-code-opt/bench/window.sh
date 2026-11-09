#!/bin/bash
# window.sh <comando...> (root): libera a GPU (para sddm + daemons), roda o comando e SEMPRE restaura no fim (trap):
# modulos stock de volta, daemons e sddm (autologin temporario devolve o desktop sozinho).
# SEGURANCA: se quem chama esta dentro de uma sessao do sddm (River), aborta - senao mataria o proprio Claude.
# WINDOW_DRYRUN=1 so imprime a decisao.
W=/home/tcfialho/build-optimizations/nvidia-open
cg=$(head -1 /proc/$$/cgroup); sid=$(sed -n 's/.*session-\([0-9]\+\)\.scope.*/\1/p' <<<"$cg")
svc=""; [ -n "$sid" ] && svc=$(loginctl show-session "$sid" -p Service --value 2>/dev/null)
if [[ "$svc" == sddm* ]]; then echo "ABORTA: este processo esta na sessao grafica $sid (service=$svc); parar o sddm mataria o Claude. Rode o Claude no tmux (claude-nv)."; exit 3; fi
echo "OK: fora do sddm (cgroup=$cg service=${svc:-nenhum})"; [ -n "$WINDOW_DRYRUN" ] && exit 0
restore() {
  bash $W/bench/swap.sh $W/mods/asis >/dev/null 2>&1
  systemctl start nvidia-persistenced nvidia-powerd lactd sddm
  sysctl -q kernel.panic_on_oops=0 kernel.panic=0 kernel.softlockup_panic=0 kernel.hung_task_panic=0 2>/dev/null
}
trap restore EXIT
sysctl -q kernel.panic_on_oops=1 kernel.panic=10 kernel.softlockup_panic=1 kernel.hung_task_panic=1 kernel.hung_task_timeout_secs=120 2>/dev/null
systemctl stop sddm lactd nvidia-powerd nvidia-persistenced 2>&1
sleep 2
for p in $(fuser /dev/nvidia* /dev/dri/* 2>/dev/null | tr -s ' '); do kill -9 $p 2>/dev/null; done   # sobras exatas por PID (sunshine, Xwayland...)
sleep 1
"$@"
