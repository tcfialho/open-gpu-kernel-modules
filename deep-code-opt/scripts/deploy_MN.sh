#!/bin/bash
# deploy_FINAL.sh (root): instala o driver FINAL (so nvidia.ko, nvidia-modeset.ko, nvidia-uvm.ko, nvidia-drm.ko) de forma atomica, com backup e rollback.
# NAO roda sozinho: so apos o usuario dizer "deploy". Efeito apos reiniciar (ou recarregar os modulos). Rollback: rollback_FINAL.sh
set -euo pipefail
SRC=/home/tcfialho/build-optimizations/nvidia-open/mods/MN
K=$(uname -r); D=/lib/modules/$K/updates/dkms
B=/var/backups/nvidia-615.78.08-prev-FINAL-$(date +%Y%m%d-%H%M%S)
[ "$(id -u)" = 0 ] || { echo "rode como root"; exit 1; }
for m in nvidia nvidia-modeset nvidia-uvm nvidia-drm; do
  [ -f "$SRC/$m.ko" ] || { echo "falta $SRC/$m.ko"; exit 2; }
  v=$(modinfo -F vermagic "$SRC/$m.ko" | awk '{print $1}'); [ "$v" = "$K" ] || { echo "vermagic $v != $K em $m"; exit 3; }
  [ -f "$D/$m.ko.zst" ] || { echo "nao achei $D/$m.ko.zst (driver nao instalado como esperado)"; exit 4; }
done
mkdir -p "$B"; for m in nvidia nvidia-modeset nvidia-uvm nvidia-drm; do cp -a "$D/$m.ko.zst" "$B/"; done
( cd "$B" && sha256sum *.ko.zst > SHA256SUMS ); echo "$B" > /var/backups/nvidia-prev-latest.path
for m in nvidia nvidia-modeset nvidia-uvm nvidia-drm; do
  zstd -q -19 -f "$SRC/$m.ko" -o "$D/$m.ko.zst.new"
  zstd -t -q "$D/$m.ko.zst.new"; chmod --reference="$B/$m.ko.zst" "$D/$m.ko.zst.new"
  mv -f "$D/$m.ko.zst.new" "$D/$m.ko.zst"          # rename atomico por modulo
done
depmod -a "$K"
echo "DEPLOY OK. Backup do stock em $B. Efeito no proximo boot (ou recarregando os modulos). Rollback: sudo $(dirname "$SRC")/../rollback_FINAL.sh"
sha256sum "$D"/nvidia*.ko.zst
