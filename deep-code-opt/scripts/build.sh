#!/bin/bash
# build.sh <id> : compila src/ e copia .ko para mods/<id>/. Log em logs/<id>.log
set -o pipefail
W=/home/tcfialho/build-optimizations/nvidia-open; ID=$1; mkdir -p $W/logs $W/mods/$ID
FL="$(cat /home/tcfialho/build-optimizations/nvidia-open/src/.optflags)"
cd $W/src && make -j14 IGNORE_PREEMPT_RT_PRESENCE=1 NV_EXCLUDE_BUILD_MODULES='' KERNEL_UNAME=$(uname -r) modules LLVM=1 CC=clang CXX=clang++ LD=ld.lld EXTRA_CFLAGS="$FL" KCFLAGS="$FL" > $W/logs/$ID.log 2>&1
rc=$?; echo "make rc=$rc"; [ $rc -eq 0 ] || { tail -15 $W/logs/$ID.log; exit $rc; }
for f in nvidia nvidia-modeset nvidia-uvm nvidia-drm; do p=$(find $W/src/kernel-open -maxdepth 1 -name $f.ko); [ -n "$p" ] || { echo missing $f; exit 3; }; cp $p $W/mods/$ID/; done
# vermagic e AVX: kernel space nao pode usar ymm/zmm
modinfo -F vermagic mods/$ID/nvidia.ko 2>/dev/null || modinfo -F vermagic $W/mods/$ID/nvidia.ko
echo "ymm/zmm: $(for f in $W/mods/$ID/*.ko; do objdump -d $f 2>/dev/null | grep -cE '%[yz]mm'; done | paste -sd+ | bc)"
