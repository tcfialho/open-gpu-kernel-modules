#!/bin/bash
# hyp_run.sh <id> <campeao-json-name> : (root, dentro da janela) compila o working tree, 1 recarga + bateria <=60s, decide.
set -e
cd /home/tcfialho/build-optimizations/nvidia-open
ID=$1; CH=$2
sudo -u tcfialho ./build.sh $ID > state_build_$ID.log 2>&1 || { tail -5 state_build_$ID.log; echo "BUILD FALHOU"; exit 3; }
python3 bench/measure2.py $ID mods/$ID --runs 6 --chunks 40 --scale 1.2
chown -R tcfialho: bench/results2
cd bench && sudo -u tcfialho python3 decide2.py $ID $CH
