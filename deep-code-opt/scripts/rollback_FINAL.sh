#!/bin/bash
# rollback_FINAL.sh (root): restaura o driver stock salvo pelo deploy_FINAL.sh (ou, se nao houver, do backup permanente do usuario).
set -euo pipefail
K=$(uname -r); D=/lib/modules/$K/updates/dkms
[ "$(id -u)" = 0 ] || { echo "rode como root"; exit 1; }
B=$(cat /var/backups/nvidia-stock-latest.path 2>/dev/null || echo /home/tcfialho/build-optimizations/backup-nvidia-stock)
for m in nvidia nvidia-modeset nvidia-uvm nvidia-drm; do
  cp -a "$B/$m.ko.zst" "$D/$m.ko.zst.new" && mv -f "$D/$m.ko.zst.new" "$D/$m.ko.zst"
done
depmod -a "$K"; echo "ROLLBACK OK a partir de $B"; sha256sum "$D"/nvidia*.ko.zst
