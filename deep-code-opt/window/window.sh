#!/bin/bash
# window.sh enter|exit (root).  enter = UMA vez: tira tela/Sunshine/daemons e descarrega nvidia (GPU livre p/ a campanha toda).
#                               exit  = fim da campanha (ou emergencia): reboot na entrada 120Hz -> autologin River.
W=/home/tcfialho/build-optimizations/nvidia-open; S=$W/auto/state; U=1000
E120='CachyOS-HDMI-virtual-120Hz.linux-xanmod-edge-custom-+-HDMI-A-1-virtual-1080p120'
say() { echo "$(date '+%F %T') $*" | tee -a $S/window.log; }
case "$1" in
exit) say "EXIT -> reboot $E120"; sync; systemctl reboot --boot-loader-entry="$E120" || systemctl reboot; exit 0;;
enter) ;;
*) echo "uso: window.sh enter|exit"; exit 2;;
esac
exec 9>/run/nvopt-window.lock; flock -n 9 || { say "janela ja aberta"; exit 4; }
tp=$(sudo -u tcfialho tmux -L claude-nv display-message -p '#{pid}' 2>/dev/null)
[ -n "$tp" ] || { say "ABORTA: tmux claude-nv nao esta rodando"; exit 3; }
grep -q 'session-[0-9]*\.scope' /proc/$tp/cgroup && { say "ABORTA: tmux dentro de session-*.scope"; exit 3; }
[ -n "$WINDOW_DRYRUN" ] && { say "DRYRUN OK tmux=$tp $(head -1 /proc/$tp/cgroup)"; exit 0; }
sysctl -a 2>/dev/null | grep -E '^kernel\.(panic|panic_on_oops|softlockup_panic|hung_task_panic|hung_task_timeout_secs) ' > $S/sysctl.orig
sysctl -q kernel.panic_on_oops=1 kernel.panic=10 kernel.softlockup_panic=1 kernel.hung_task_panic=1 kernel.hung_task_timeout_secs=120
say "ENTER: isolando GPU"
systemctl mask --runtime sunshine-prelogin.service >/dev/null 2>&1
sudo -u tcfialho XDG_RUNTIME_DIR=/run/user/$U systemctl --user stop sunshine-after-login.service
systemctl stop sunshine-prelogin.service; systemctl stop sddm; sleep 2; systemctl stop sunshine-prelogin.service
systemctl stop lactd nvidia-powerd nvidia-persistenced
for i in 1 2 3 4 5; do
  H=$(fuser /dev/nvidia* /dev/dri/* 2>/dev/null | tr -s ' ' '\n' | grep -E '^[0-9]+$' | sort -u)
  [ -z "$H" ] && break
  for p in $H; do c=$(cat /proc/$p/comm 2>/dev/null)
    case "$c" in sunshine*|Xwayland|river|kitty|Xorg|sddm*|lact*|nvidia-*|maindeck*|wl-*) [ $i -ge 3 ] && kill -9 $p 2>/dev/null || kill $p 2>/dev/null;;
    *) say "holder desconhecido $p ($c)";; esac; done
  sleep 2; done
H=$(fuser /dev/nvidia* /dev/dri/* 2>/dev/null | tr -s ' ' '\n' | grep -E '^[0-9]+$' | sort -u)
[ -n "$H" ] && { say "FALHA: holders restantes $H -> exit/reboot"; exec $0 exit; }
for m in nvidia_drm nvidia_uvm nvidia_modeset nvidia; do lsmod | grep -q "^$m " && { rmmod $m || { say "rmmod $m falhou -> reboot"; exec $0 exit; }; }; done
say "ENTER OK: GPU livre, modulos descarregados"
# sinal de vida com a tela apagada: Caps Lock pisca ate o reboot do exit
setsid bash -c 'while :; do for l in /sys/class/leds/*::capslock/brightness; do echo 1 > $l; done; sleep 0.4; for l in /sys/class/leds/*::capslock/brightness; do echo 0 > $l; done; sleep 1.6; done' </dev/null >/dev/null 2>&1 &
