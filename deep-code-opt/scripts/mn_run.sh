#!/bin/bash
# mn_run.sh (root, destacado via systemd-run): mede FINAL x MN (FINAL + -march=native sem SIMD no nucleo RM), A/B/A/B, 1 recarga por medicao.
# Tira a tela (GPU livre), mede ~4 min, volta FINAL instalado + servicos + sddm. Log: state_mn.log
W=/home/tcfialho/build-optimizations/nvidia-open; B=$W/bench; LOG=$W/state_mn.log; U=1000
exec > >(tee -a $LOG) 2>&1
say() { echo "$(date '+%T') $*"; }
restore() {
  say "RESTORE: FINAL instalado + servicos"
  for m in nvidia_drm nvidia_uvm nvidia_modeset nvidia; do lsmod | grep -q "^$m " && rmmod $m; done
  modprobe nvidia_drm; modprobe nvidia_uvm
  bash $B/restore_noise.sh
  sysctl -q --system
  systemctl start nvidia-persistenced nvidia-powerd lactd
  systemctl unmask --runtime sunshine-prelogin.service 2>/dev/null
  systemctl start sddm
  say "srcversion carregado=$(cat /sys/module/nvidia/srcversion) FINAL=$(modinfo -F srcversion $W/mods/FINAL/nvidia.ko)"
  chown -R tcfialho: $B/results2 $LOG
  say MNRUN_DONE
}
trap restore EXIT
say "== inicio FINAL x MN"
sysctl -q kernel.panic_on_oops=1 kernel.panic=10 kernel.softlockup_panic=1 kernel.hung_task_panic=1 kernel.hung_task_timeout_secs=120
systemctl mask --runtime sunshine-prelogin.service >/dev/null 2>&1
sudo -u tcfialho XDG_RUNTIME_DIR=/run/user/$U systemctl --user stop sunshine-after-login.service
systemctl stop sunshine-prelogin.service sddm; sleep 2; systemctl stop sunshine-prelogin.service lactd nvidia-powerd nvidia-persistenced
# sessao grafica antiga: os lacos do river/init sobrevivem ao sddm e religam maindeck/mako sem compositor -> piscada no proximo login
for s in $(loginctl list-sessions --no-legend | awk '$3=="tcfialho"{print $1}'); do
  [ "$(loginctl show-session $s -p Type --value)" = wayland ] && { say "encerrando sessao grafica $s"; loginctl terminate-session $s; }
done
sleep 2
for i in 1 2 3 4 5; do
  H=$(fuser /dev/nvidia* /dev/dri/* 2>/dev/null | tr -s ' ' '\n' | grep -E '^[0-9]+$' | sort -u)
  [ -z "$H" ] && break
  for p in $H; do c=$(cat /proc/$p/comm 2>/dev/null)
    case "$c" in sunshine*|Xwayland|river|kitty|Xorg|sddm*|lact*|nvidia-*|maindeck*|wl-*) [ $i -ge 3 ] && kill -9 $p 2>/dev/null || kill $p 2>/dev/null;;
    *) say "holder desconhecido $p ($c)";; esac; done
  sleep 2; done
H=$(fuser /dev/nvidia* /dev/dri/* 2>/dev/null | tr -s ' ' '\n' | grep -E '^[0-9]+$' | sort -u)
[ -n "$H" ] && { say "ABORTA: holders restantes $H"; exit 3; }
bash $B/noise.sh
cd $B
for p in "MNF1 FINAL" "MN1 MN" "MNF2 FINAL" "MN2 MN"; do set -- $p; say "medindo $1 ($2)"; python3 measure2.py $1 ../mods/$2 --runs 6 --chunks 40 --scale 1.2 | tail -1; done
python3 - <<'PY'
import json
for out, parts in (("MNall", ("MN1", "MN2")), ("MNFall", ("MNF1", "MNF2"))):
    d = [json.load(open(f"results2/{p}.json")) for p in parts]
    m = dict(d[0]); m["name"] = out; m["runs"] = d[0]["runs"] + d[1]["runs"]
    m["module_reloads"] = 2; m["xid_new"] = sum(x.get("xid_new") or 0 for x in d); json.dump(m, open(f"results2/{out}.json", "w"))
PY
say "== carga 1"; python3 decide2.py MN1 MNF1 | tail -9
say "== carga 2"; python3 decide2.py MN2 MNF2 | tail -9
say "== juntas"; python3 decide2.py MNall MNFall | tail -9
