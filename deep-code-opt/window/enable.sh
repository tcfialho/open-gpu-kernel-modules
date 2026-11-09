#!/bin/bash
# enable.sh (root): autologin + agente + viewer no River + default 120Hz no Limine. Tudo com backup; cleanup.sh desfaz.
A=/home/tcfialho/build-optimizations/nvidia-open/auto; set -e
rm -f $A/MISSION_DONE
[ -f /etc/sddm.conf.nvopt-backup ] || cp -p /etc/sddm.conf /etc/sddm.conf.nvopt-backup
printf '[Autologin]\nUser=tcfialho\nSession=river.desktop\nRelogin=false\n' > /etc/sddm.conf
[ -f /boot/limine.conf.nvopt-backup ] || cp -p /boot/limine.conf /boot/limine.conf.nvopt-backup
sed -i 's|^default_entry:.*|default_entry: CachyOS HDMI virtual 120Hz/linux-xanmod-edge-custom + HDMI-A-1 virtual 1080p120|' /boot/limine.conf
grep -q '^default_entry: CachyOS HDMI virtual 120Hz/' /boot/limine.conf
RI=/home/tcfialho/.config/river/init
grep -q 'nvopt-viewer' $RI || { cp -p $RI $RI.nvopt-backup; sed -i '/^wl-clip-persist /i # nvopt-viewer (campanha; cleanup remove)\n[ -f /home/tcfialho/build-optimizations/nvidia-open/auto/ENABLED ] \&\& [ ! -f /home/tcfialho/build-optimizations/nvidia-open/auto/MISSION_DONE ] \&\& kitty --title "Campanha NVIDIA" /home/tcfialho/build-optimizations/nvidia-open/auto/viewer.sh \&' $RI; }
grep -q nvopt-viewer $RI
loginctl enable-linger tcfialho
touch $A/ENABLED; chown -R tcfialho: $A
sudo -u tcfialho XDG_RUNTIME_DIR=/run/user/1000 systemctl --user daemon-reload
sudo -u tcfialho XDG_RUNTIME_DIR=/run/user/1000 systemctl --user enable nvopt-agent.service
echo "enable ok"
