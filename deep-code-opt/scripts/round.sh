#!/bin/bash
# round.sh <campeao-json> <hip1> [hip2...]   (root, janela aberta). Hipotese a hipotese: aplica (se ainda nao aplicada), compila, 1 recarga, <=60s, decide, commita/reverte, hyp-add.
# env META=hyps/meta_rN.json  FIRST_APPLIED=1 (a 1a hipotese ja esta no working tree)
cd /home/tcfialho/build-optimizations/nvidia-open
CH=$1; shift; META=${META:-hyps/meta_r1.json}; U="sudo -u tcfialho"
GIT="$U git -C src -c user.name=Claude(campanha) -c user.email=noreply@anthropic.com"
n=0
for H in "$@"; do
  n=$((n+1))
  if ! { [ "$n" = 1 ] && [ -n "$FIRST_APPLIED" ]; }; then $U python3 hyps/$H.py || { echo "FALHA aplicar $H"; exit 4; }; fi
  echo "##### $H  campeao=$CH  $(date +%T)"
  bench/hyp_run.sh $H $CH || { echo "FALHA $H (build/medicao)"; exit 5; }
  D=$(python3 -c "import json;d=json.load(open('bench/results2/${H}_decision.json'));print(d['decision'])")
  $U mkdir -p /home/tcfialho/Documents/poc/nvidia-open-opt/patches
  $U bash -c "git -C src diff > /home/tcfialho/Documents/poc/nvidia-open-opt/patches/${H}.patch"
  if [ "$D" = "ACEITA" ]; then $GIT commit -q -am "$H: aceita" && CH=$H; else $GIT checkout -q -- .; fi
  $U python3 hyps/hypadd.py "$H" "$META"
  echo "##### $H => $D (campeao agora: $CH)"
done
echo "CAMPEAO_FINAL=$CH"
