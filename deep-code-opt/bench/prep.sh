#!/bin/bash
# Libera a GPU: para display manager e daemons que seguram /dev/nvidia*. Requer root.
systemctl stop sddm lactd nvidia-powerd nvidia-persistenced 2>&1
pkill -x sunshine 2>/dev/null
sleep 2
fuser -v /dev/nvidia* /dev/dri/* 2>&1 | grep -v '^ *USU' || true
