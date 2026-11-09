#!/bin/bash
# Retomavel: pula IDs do ledger; se o boot anterior morreu no meio de um ID, registra rejeitado.
W=/home/tcfialho/build-optimizations/nvidia-open; cd $W
sysctl -q kernel.panic_on_oops=1 kernel.panic=10 kernel.softlockup_panic=1 kernel.hung_task_panic=1 kernel.hung_task_timeout_secs=120
bash bench/prep.sh >/dev/null 2>&1
if [ -f logs/current_id ]; then
  C=$(cat logs/current_id)
  grep -q "\"id\": *\"$C\"" bench/results/ledger.jsonl || { git -C src checkout -q .; echo "{\"id\":\"$C\",\"accepted\":false,\"reason\":\"REJEITADO: oops/hang do kernel durante o teste\",\"delta_pct\":{}}" >> bench/results/ledger.jsonl; }
  rm -f logs/current_id
fi
for ID in R1H1 R1H2 R1H3 R1H4 R1H5 R2H1 R2H2 R2H3 R2H4 R2H5 R3H1 R3H2 R3H3 R3H4 R3H5 R4H1 R4H2 R4H3 R4H4 R4H5 R5H1 R5H2 R5H3 R5H4; do
  grep -q "\"id\": *\"$ID\"" bench/results/ledger.jsonl 2>/dev/null && continue
  DESC=$(python3 hyps.py $ID 2>&1) || { echo "$ID APPLY FAIL: $DESC"; git -C src checkout -q .; echo "{\"id\":\"$ID\",\"accepted\":false,\"reason\":\"patch nao aplicavel\",\"delta_pct\":{}}" >> bench/results/ledger.jsonl; continue; }
  echo $ID > logs/current_id
  echo "=== $ID: $DESC"; ./hyp.sh $ID "$DESC"
  rm -f logs/current_id
done
echo ALL_DONE; touch logs/ALL_DONE
