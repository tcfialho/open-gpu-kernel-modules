#!/bin/bash
# ablate_run.sh (root, janela aberta): leave-one-out intercalado com o campeao repetido. 1 recarga por medicao.
cd /home/tcfialho/build-optimizations/nvidia-open/bench
M() { python3 measure2.py "$1" "../mods/$2" --runs 6 --chunks 40 --scale 1.2 | tail -1; }
M abl_c2 R4H2 ; M abl_R1H1 abl_R1H1; M abl_R2H2 abl_R2H2
M abl_c3 R4H2 ; M abl_R2H3 abl_R2H3; M abl_R3H1 abl_R3H1
M abl_c4 R4H2 ; M abl_R3H4 abl_R3H4; M abl_R4H2 abl_R4H2
M abl_c5 R4H2 ; M abl_R4H1 abl_R4H1; M abl_ISRGATE abl_ISRGATE
M abl_c6 R4H2
chown -R tcfialho: results2
echo ABLATE_OK
