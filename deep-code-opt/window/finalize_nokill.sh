#!/bin/bash
# finalize_nokill.sh (root): encerra a campanha SEM reboot e SEM matar o tmux/Claude: desativa o autostart, restaura configs e servicos.
# O FINAL segue carregado em memoria (nao instalado); proximo boot volta ao stock ate o usuario dizer "deploy".
A=/home/tcfialho/build-optimizations/nvidia-open/auto; RI=/home/tcfialho/.config/river/init; UENV="XDG_RUNTIME_DIR=/run/user/1000"
touch $A/MISSION_DONE; rm -f $A/ENABLED
sudo -u tcfialho env $UENV systemctl --user disable nvopt-agent.service          # sem --now: parar a unidade mataria o tmux desta sessao
[ -f /etc/sddm.conf.nvopt-backup ] && mv -f /etc/sddm.conf.nvopt-backup /etc/sddm.conf
[ -f /boot/limine.conf.nvopt-backup ] && mv -f /boot/limine.conf.nvopt-backup /boot/limine.conf
[ -f $RI.nvopt-backup ] && mv -f $RI.nvopt-backup $RI
systemctl unmask --runtime sunshine-prelogin.service 2>/dev/null
sysctl -q --system                                                                 # volta panic/hung_task ao normal
for s in nvidia-persistenced nvidia-powerd lactd; do systemctl start $s.service 2>&1 | head -1; done
sudo -u tcfialho env $UENV systemctl --user start sunshine-after-login.service 2>&1 | head -1
sleep 3
for s in nvidia-persistenced nvidia-powerd lactd; do echo "$s: $(systemctl is-active $s.service)"; done
echo "sunshine-after-login: $(sudo -u tcfialho env $UENV systemctl --user is-active sunshine-after-login.service)"
echo "autostart: $(sudo -u tcfialho env $UENV systemctl --user is-enabled nvopt-agent.service 2>&1 | head -1); MISSION_DONE: $(ls $A/MISSION_DONE)"
echo "modulos: $(lsmod | awk '/^nvidia/{printf "%s ",$1}') srcversion=$(cat /sys/module/nvidia/srcversion)"
echo "FINALIZE_OK"
