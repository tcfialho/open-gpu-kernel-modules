#!/bin/bash
# hyp.sh <ID> "<desc>": build, UMA carga do candidato (~20s), compara com referencia do campeao, decide, commita ou reverte.
W=/home/tcfialho/build-optimizations/nvidia-open; ID=$1; DESC=$2; cd $W
./build.sh $ID > logs/$ID.build.txt 2>&1 || { echo "BUILD FAIL"; tail -20 logs/$ID.build.txt; git -C src checkout -q . ; echo "{\"id\":\"$ID\",\"desc\":\"$DESC\",\"accepted\":false,\"reason\":\"falha de build\",\"delta_pct\":{}}" >> bench/results/ledger.jsonl; exit 1; }
sudo python3 -I bench/measure1.py $ID $W/mods/$ID --ref bench/results/ref_champ.json > logs/$ID.measure.txt 2>&1 || { tail -5 logs/$ID.measure.txt; echo MEASURE FAIL; exit 2; }
D=$(python3 bench/decide.py bench/results/$ID.json)
ACC=$(echo "$D" | python3 -c 'import json,sys;print(json.load(sys.stdin)["accepted"])')
if [ "$ACC" = "True" ]; then
  sudo python3 -I bench/measure1.py ${ID}_confirm $W/mods/$ID --ref bench/results/ref_champ.json > logs/$ID.confirm.txt 2>&1
  D=$(python3 bench/decide.py bench/results/$ID.json bench/results/${ID}_confirm.json)
  ACC=$(echo "$D" | python3 -c 'import json,sys;print(json.load(sys.stdin)["accepted"])')
fi
if [ "$ACC" = "True" ]; then
  git -C src commit -qam "$ID: $DESC" && rm -rf mods/champ && cp -r mods/$ID mods/champ
  sudo python3 -I bench/measure1.py ref_champ $W/mods/champ --loads 3 --runs 5 > logs/$ID.newref.txt 2>&1
else git -C src checkout -q .; fi
python3 - "$ID" "$DESC" "$D" <<'PY' >> bench/results/ledger.jsonl
import json,sys; d=json.loads(sys.argv[3]); d.update(id=sys.argv[1],desc=sys.argv[2]); print(json.dumps(d))
PY
echo "$ID accepted=$ACC"; echo "$D" | python3 -c 'import json,sys;d=json.load(sys.stdin);print(d["reason"])'
