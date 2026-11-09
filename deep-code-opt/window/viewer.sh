#!/bin/bash
# aberto pelo River no login: so MOSTRA a campanha (attach). Nunca cria outro Claude.
for i in $(seq 1 60); do tmux -L claude-nv has-session -t claude-nv 2>/dev/null && exec tmux -L claude-nv attach-session -t claude-nv; sleep 2; done
echo "campanha indisponivel: $(systemctl --user is-active nvopt-agent.service)"; tail -5 /home/tcfialho/build-optimizations/nvidia-open/auto/state/agent.log; read -r
