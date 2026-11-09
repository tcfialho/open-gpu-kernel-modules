#!/bin/bash
# cleanup.sh (root): desfaz tudo da campanha.
A=/home/tcfialho/build-optimizations/nvidia-open/auto; RI=/home/tcfialho/.config/river/init
touch $A/MISSION_DONE; rm -f $A/ENABLED
sudo -u tcfialho XDG_RUNTIME_DIR=/run/user/1000 systemctl --user disable --now nvopt-agent.service
sudo -u tcfialho tmux -L claude-nv kill-server 2>/dev/null
rm -f /home/tcfialho/.config/systemd/user/nvopt-agent.service; sudo -u tcfialho XDG_RUNTIME_DIR=/run/user/1000 systemctl --user daemon-reload
[ -f /etc/sddm.conf.nvopt-backup ] && mv -f /etc/sddm.conf.nvopt-backup /etc/sddm.conf
[ -f /boot/limine.conf.nvopt-backup ] && mv -f /boot/limine.conf.nvopt-backup /boot/limine.conf
[ -f $RI.nvopt-backup ] && mv -f $RI.nvopt-backup $RI
systemctl unmask --runtime sunshine-prelogin.service 2>/dev/null; sysctl -q --system
echo "cleanup ok"
