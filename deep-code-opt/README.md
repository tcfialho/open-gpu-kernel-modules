# deep-code-opt: otimização do driver NVIDIA open (615.78.08)

Campanha de otimização do `nvidia.ko` (open kernel module) numa RTX 4050 Laptop (Ada, GSP), kernel 7.3 xanmod, Clang 23 + ThinLTO.
Esta pasta guarda **o método, o harness e os resultados**; o código otimizado está nos commits da branch `opt/615.78.08-isr`.

## Resultado

| Versão | fence_block | uvm_prefetch2m | alloc2m | hostreg1m | ctx_create |
|---|--:|--:|--:|--:|--:|
| FINAL (só caminho de interrupção) vs original | **-24,4%** | **-16,4%** | -0,6% | -0,2% (empate) | +0,2% (empate) |
| MN (FINAL + `-march=native` sem SIMD) vs FINAL | **-1,7%** | **-1,4%** | **-1,9%** | **-3,8%** | **-1,1%** |

Controles (`submit_spin`, `h2d64k`) ficam em 0%. 0 Xid em todas as medições. IRQs por fence: 1,0 antes e depois (o ganho vem de menos leituras MMIO por IRQ, não de menos IRQs).
Impacto em uso real: **não esperar ganho de FPS** (~6 µs por fence contra um frame de 8333 µs); é ganho de CPU de kernel.

## Onde está cada coisa

| Caminho | O que é |
|---|---|
| `docs/METHODOLOGY.md` | protocolo de medição e regra de decisão (o que vale como ganho) |
| `docs/FIELD_NOTES.md` | **dificuldades não óbvias**: janela sem GPU, login automático, piscadas, flags que o kernel recusa, armadilhas do `perf` |
| `bench/` | harness CUDA (`harness2.cu`), medição (`measure2.py`), decisão (`decide2.py`), perfil (`prof_*.sh`), ruído (`noise.sh`), troca de módulo (`swap.sh`), resultados brutos (`results2/*.json`) |
| `hyps/` | uma aplicação por hipótese (`R<rodada>H<n>.py`) e metadados |
| `scripts/` | orquestração: rodadas, ablação, medição final, smoke de display, deploy e rollback |
| `window/` | janela GPU-livre, autologin, agente retomando no boot, limpeza |
| `reports/` | relatório da Fase 6 (25 hipóteses, ganho/perda e motivo), parecer do Judge, gráficos HTML |
| `patches/` | diffs por hipótese, FINAL contra original e contra a tag upstream |

## As 25 hipóteses em uma linha

Mantidas (ISR): `R2H2` (EN_SET só se LEAF≠0), `R3H1` (leaves de stall sob demanda), `R3H2`+`R4H1` (gate/serviço non-stall direto).
Passaram na rodada mas **removidas** (ablação < 1%): `R1H1`, `R2H3`, `R3H4`, `R4H2`.
As outras 17 foram recusadas: polling do GSP e espera do UVM são limitados pelo tempo do GSP/GPU, micro-otimização de CPU ali não muda nada. Tabela completa em `reports/relatorio_fase6.md`.

## Reproduzir

Os scripts têm caminhos absolutos (`/home/tcfialho/build-optimizations/nvidia-open`); ajuste `W=` no topo de cada um.
1. Fonte: tag upstream `615.78.08` + commit `packaging` (patches do pacote instalado) + commits da branch.
2. Build: `scripts/build.sh <id>` (usa `src/.optflags`), saída em `mods/<id>/*.ko`.
3. Medir: leia `docs/FIELD_NOTES.md` antes. **A medição apaga a tela** (descarrega o `nvidia.ko`).
4. Deploy: `scripts/deploy_FINAL.sh` (backup do stock + troca atômica); `scripts/rollback_FINAL.sh` desfaz.
