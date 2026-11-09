# Metodologia

## Alvo e métrica
Módulos `nvidia`, `nvidia-modeset`, `nvidia-uvm`, `nvidia-drm`. Métrica: **ciclos de CPU em modo kernel** (`perf` `cycles:k`) ou tempo de parede, por operação, em oito cenários (`bench/harness2.cu`, variável `SCEN`).

| Cenário | Exercita | Papel |
|---|---|---|
| `submit_spin`, `h2d64k` | quase nada do módulo (9 e 14 kcyc/op) | **controle**: tem que dar 0% |
| `fence_block` | submissão + espera de fence = caminho de IRQ | principal |
| `alloc2m`, `hostreg1m`, `uvm_prefetch2m` | RM/UVM, RPCs ao GSP | principal |
| `ctx_create` | criação de contexto CUDA (muitos RPCs) | principal |
| `nvenc1080p` | NVENC | **alterna ~0,9% por layout do binário**: faixa 0,7–1,1% é ignorada |

## Protocolo
1. Uma **recarga de módulo por hipótese** (a tela fica apagada durante a medição).
2. Bateria ≤ 60 s incluindo a troca (na prática ~49 s): 6 execuções × 40 chunks, mediana por carga, fixa no P-core 2 (`taskset -c 2`).
3. Ruído congelado por `bench/noise.sh` (turbo off, pstate 60%, SMT irmão offline, irqbalance off, IRQs fora do core 2, `cpu_dma_latency=0`, clock da GPU travado em 1500 MHz). `bench/restore_noise.sh` desfaz.
4. A/A (mesmo binário contra si): MAD entre cargas ≤ 0,25%.
5. Campeão medido de novo **a cada hipótese** (o campeão muda); decisão contra o campeão da época.

## Regra de decisão (`bench/decide2.py`)
Aceita se algum cenário principal tem Δ ≤ −0,5% **e** |Δ| > 2×MAD, as duas metades (execuções pares/ímpares) concordam, e nenhum cenário regride > 0,5% com > 2×MAD. Senão reverte na hora.

## Validação independente (o que realmente separou ganho de ruído)
- **Ablação leave-one-out** (`scripts/ablate_run.sh`): remove uma mudança do campeão e mede em 6 cargas do campeão. Quatro hipóteses que passaram na rodada deram < 1% e foram removidas.
- **A/B/A/B intercalado** final contra o original (`scripts/final_run.sh`) + contagem de IRQs por fence + `dmesg` limpo.
- **Smoke de display** com o módulo novo (`scripts/smoke_display.sh`): sddm/River, `vkcube`, `glxgears`, 0 erros novos.

## Lições
- Passar na rodada **não** prova ganho: efeito de layout do binário e ruído entre cargas aparecem como "ganho" de 0,5–1%.
- Metades pares/ímpares da mesma carga não detectam efeito de layout; só carga nova + ablação.
- Cenário de controle precisa existir, senão qualquer drift é lido como efeito.
- Medir antes de teorizar: o gargalo (leituras MMIO PCIe, ~0,6 µs cada, repetidas na ISR) só apareceu com o perfil **dentro do laço**.
