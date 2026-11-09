#!/bin/bash
# swap.sh <dir com nvidia*.ko> : descarrega nvidia e carrega o conjunto dado. Requer root.
set -e
D=$1
for m in nvidia_drm nvidia_uvm nvidia_modeset nvidia; do lsmod | grep -q "^$m " && rmmod $m; done
insmod $D/nvidia.ko NVreg_InitializeSystemMemoryAllocations=0 NVreg_EnableGpuFirmware=1 NVreg_DynamicPowerManagement=0x00
insmod $D/nvidia-modeset.ko
insmod $D/nvidia-uvm.ko
insmod $D/nvidia-drm.ko modeset=1
nvidia-smi -pm 1 >/dev/null 2>&1; nvidia-smi -lgc 1500,1500 >/dev/null 2>&1
sleep 1
