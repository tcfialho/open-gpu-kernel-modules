#!/bin/bash
# systemd --user (linger). Unico criador do Claude da campanha: tmux interativo FORA da sessao do sddm, cwd = projeto (trust persistente).
A=/home/tcfialho/build-optimizations/nvidia-open/auto; T=(tmux -L claude-nv); SID=$(cat $A/SESSION_ID); LOG=$A/state/agent.log
exec 8>$A/state/agent.lock; flock -n 8 || { echo "$(date '+%F %T') outro agent ativo" >> $LOG; exit 0; }
[ -f $A/MISSION_DONE ] && exit 0
cd /home/tcfialho/build-optimizations/nvidia-open || exit 1
echo "$(date '+%F %T') boot=$(cat /proc/sys/kernel/random/boot_id)" >> $A/state/boots.log
# nao rodar 2 Claudes da mesma conversa: se ha um Claude interativo entregando a vez (HANDOFF_PID), espera ele sair
while [ -f $A/HANDOFF_PID ] && kill -0 "$(cat $A/HANDOFF_PID)" 2>/dev/null; do sleep 3; done
rm -f $A/HANDOFF_PID
if ! "${T[@]}" has-session -t claude-nv 2>/dev/null; then
  "${T[@]}" new-session -d -s claude-nv -x 220 -y 55 -c /home/tcfialho/build-optimizations/nvidia-open \
    claude --resume "$SID" --effort max "$(cat $A/PROMPT)"
  echo "$(date '+%F %T') claude iniciado no tmux" >> $LOG
fi
while "${T[@]}" has-session -t claude-nv 2>/dev/null; do sleep 15; done
echo "$(date '+%F %T') sessao tmux terminou" >> $LOG
