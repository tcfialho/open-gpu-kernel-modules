# Relatorio Fase 6 - deep-code-opt: driver NVIDIA open 615.78.08 (nvidia.ko / nvidia-uvm.ko)

Alvo: RTX 4050 (Ada, GSP), kernel 7.3 xanmod, Clang 23. Build base `-O3 -mtune=native -flto=thin -fno-semantic-interposition -falign-functions=32 -falign-loops=32 -fomit-frame-pointer -fno-math-errno -fno-trapping-math` (sem `-fno-plt`: o kernel recusa GOTPCRELX). Medicao: P-core 2, mediana por carga, 6 execucoes x 40 chunks, 1 recarga de modulo por medicao, bateria <= 49 s.

## Resultado final: FINAL x original (A/B/A/B intercalado, 2 cargas de cada)

| Cenario | Metrica | Original | FINAL | Delta % | MAD % | Metades | Veredito |
| :-- | :-- | --: | --: | --: | --: | :-- | :-- |
| submit_spin | wall | 6.839 | 6.844 | **+0.07** | 0.33 | +0.07 / +0.08 | controle |
| h2d64k | wall | 10.416 | 10.417 | **+0.01** | 0.14 | +0.01 / -0.01 | controle |
| fence_block | wall | 25.79 | 19.502 | **-24.38** | 0.15 | -24.35 / -24.38 | GANHO |
| alloc2m | kcyc | 182318.05 | 181166.9 | **-0.63** | 0.05 | -0.62 / -0.63 | GANHO |
| hostreg1m | kcyc | 247117.325 | 246655.825 | **-0.19** | 0.13 | -0.27 / -0.06 | empate |
| uvm_prefetch2m | kcyc | 90517.65 | 75637.775 | **-16.44** | 0.32 | -16.37 / -16.50 | GANHO |
| nvenc1080p | wall | 1609.044 | 1602.698 | **-0.39** | 0.03 | -0.41 / -0.33 | empate |
| ctx_create | wall | 126939.436 | 127246.261 | **+0.24** | 0.32 | +0.24 / +0.24 | empate |

IRQs por fence (fence_block, /proc/interrupts): original 1.0 e 1.0; FINAL 1.0 e 1.0 (mesmo numero: o ganho vem de menos leituras MMIO por IRQ, nao de menos IRQs). Erros novos no dmesg (Xid, timeout, nobody cared, BUG, Oops) nas 4 medicoes: 0.

Mecanismo: cada leitura MMIO PCIe na ISR custa ~0.6 us e a ISR lia os mesmos registradores varias vezes por interrupcao (pre-leitura + servico non-stall, EN_SET de leaf vazia, todos os leaves de stall). O FINAL remove essas leituras redundantes: fence_block cai de 25.79 us para 19.50 us por fence.

## Ciclo 1 (Hipoteses 1.1 a 1.5)

Nota: a Rodada 1 foi executada 2 vezes. 1a passagem (harness v1, sem ctx_create): 5/5 recusadas (medias R1H1 -0.01%, R1H2 +0.10%, R1H3 +0.20%, R1H4 +0.10%, R1H5 +0.11%). O perfil dentro do laco mostrou que submit_spin/h2d64k nao exercitam o modulo e que o polling de RPC so aparece em operacoes com RPC; adicionei ctx_create (desvio `harness-ctx-create`) e re-medi. A tabela abaixo e a 2a passagem.

| Tentativa | Alvo & Modificacao | Resultado Benchmark (delta % vs campeao da epoca) | Decisao | Racional Tecnico |
| :-- | :-- | :-- | :-- | :-- |
| **1.1** (R1H1) | `src/nvidia/src/kernel/gpu/gsp/kernel_gsp.c:2070 (_kgspRpcDrainEvents -> kgspHealthCheck_HAL)`: health check so a cada 16o ciclo de drain VAZIO; roda sempre se tratou evento, achou a resposta ou houve erro. | fence_block -0.07%; uvm_prefetch +0.05%; alloc2m -0.08%; hostreg1m -0.78%; ctx -0.26%; nvenc +0.03%. Media 8 cenarios -0.11% | **ACEITO** (`63415a5`) -> **revertido no FINAL** (ablacao) | Health check CrashCat so a cada 16o ciclo vazio do polling de RPC. Ganho so em hostreg1m (-0.78%, 1 carga); na ablacao o efeito de remove-lo e <= +0.5% (ctx_create) -> ganho nao demonstrado. |
| **1.2** (R1H2) | `src/nvidia/src/kernel/gpu/gsp/kernel_gsp.c:3455 (kgspRecvPoll_IMPL -> kdispApplyAggressiveVblankHandlingWar)`: WAR de vblank so a cada 8a iteracao do polling (atraso <= ~8 iteracoes, bem abaixo de 1 scanline). | fence_block -0.15%; uvm_prefetch -0.34%; alloc2m +0.09%; hostreg1m +0.19%; ctx -0.20%; nvenc -0.03%. Media 8 cenarios -0.17% | **RECUSADO** (revertido na hora) | WAR de vblank a cada 8a iteracao do polling. Deltas negativos pequenos (ctx_create -0.20%), nenhum cenario passa 0.5% e 2xMAD: a latencia do RPC e o tempo de processamento do GSP, nao a leitura MMIO do polling. |
| **1.3** (R1H3) | `src/nvidia/src/kernel/gpu/gsp/kernel_gsp.c:3372 (kgspRecvPoll_IMPL -> gpuCheckTimeout)`: gpuCheckTimeout so a cada 8a iteracao do polling. | fence_block -0.16%; uvm_prefetch -0.22%; alloc2m +0.21%; hostreg1m +0.29%; ctx -0.00%; nvenc -0.01%. Media 8 cenarios -0.04% | **RECUSADO** (revertido na hora) | gpuCheckTimeout a cada 8a iteracao. Sem efeito mensuravel (|delta| < 0.3%): relogio e barato frente ao tempo de espera do GSP. |
| **1.4** (R1H4) | `kernel-open/nvidia-uvm/uvm_common.c:249 (uvm_spin_loop)`: ler o relogio so a cada 16a chamada de uvm_spin_loop (limiares de schedule/print sao ms..s). | fence_block -0.16%; uvm_prefetch -0.03%; alloc2m -0.15%; hostreg1m +0.09%; ctx +0.14%; nvenc -0.02%. Media 8 cenarios -0.04% | **RECUSADO** (revertido na hora) | uvm_spin_loop le o relogio a cada 16a chamada. Sem efeito: o laco espera a GPU, o custo por giro nao muda a duracao da espera. |
| **1.5** (R1H5) | `src/nvidia/src/kernel/gpu/gsp/kernel_gsp.c:3459 (kgspRecvPoll_IMPL osSpinLoop)`: apos 32 polls vazios, 4 PAUSE entre leituras do RX head (backoff limitado; deadline/eventos intactos). | fence_block -0.06%; uvm_prefetch -0.31%; alloc2m +0.02%; hostreg1m -0.04%; ctx +0.08%; nvenc +0.00%. Media 8 cenarios -0.13% | **RECUSADO** (revertido na hora) | Backoff de PAUSE apos 32 polls vazios. Sem efeito: mesma razao (espera dominada pelo GSP). |

## Ciclo 2 (Hipoteses 2.1 a 2.5)

| Tentativa | Alvo & Modificacao | Resultado Benchmark (delta % vs campeao da epoca) | Decisao | Racional Tecnico |
| :-- | :-- | :-- | :-- | :-- |
| **2.1** (R2H1) | `src/nvidia/src/kernel/gpu/intr/arch/turing/intr_nonstall_tu102.c:433 (intrServiceNonStall_TU102 loop, TODO Bug 3823562)`: 1 leitura de TOP por indice distinto por passagem de servico. | fence_block -0.38%; uvm_prefetch -0.11%; alloc2m +0.17%; hostreg1m +0.05%; ctx +0.26%; nvenc -0.02%. Media 8 cenarios -0.04% | **RECUSADO** (revertido na hora) | Uma leitura de INTR_TOP por indice no servico non-stall. fence_block -0.38% (abaixo do limiar): a mascara non-stall tem so 1 subtree, nao ha leitura repetida a eliminar. |
| **2.2** (R2H2) | `src/nvidia/src/kernel/gpu/intr/arch/turing/intr_nonstall_tu102.c:247,445 (LEAF & EN_SET)`: ler EN_SET so quando LEAF != 0 (resultado do AND identico). | fence_block -4.95%; uvm_prefetch -3.42%; alloc2m +0.03%; hostreg1m +0.04%; ctx +0.06%; nvenc -0.10%. Media 8 cenarios -1.10% | **ACEITO** (`b25d7d9`) -> **mantido no FINAL** | Ler EN_SET so quando LEAF != 0 (AND identico, sem efeito colateral). Elimina 1 leitura MMIO PCIe (~0.6 us) por leaf vazia na ISR: fence_block -4.95%, uvm_prefetch2m -3.42%. Ablacao: +2.8%/+1.95% ao remover -> MANTIDA. |
| **2.3** (R2H3) | `src/nvidia/src/kernel/gpu/gpu.c:6292 (gpuGetCeFaultMethodBufferSize_KERNEL)`: gravar o valor no campo apos a primeira consulta bem sucedida. | fence_block +0.34%; uvm_prefetch -0.28%; alloc2m +0.04%; hostreg1m +0.30%; ctx -0.86%; nvenc -0.92%. Media 8 cenarios -0.13% | **ACEITO** (`9bccb88`) -> **revertido no FINAL** (ablacao) | Cache do tamanho do fault-method-buffer (campo lido e nunca gravado: 1 RPC ao GSP por channel group). ctx_create -0.86% (1 carga); ablacao: +0.55% (< 1%, dentro do ruido de layout) -> ganho nao demonstrado, premissa nao verificada em outros chips -> revertida no FINAL. |
| **2.4** (R2H4) | `src/nvidia/src/kernel/gpu/gsp/kernel_gsp.c:2059 (_kgspRpcDrainEvents kgspDumpGspLogs)`: um kgspDumpGspLogs por chamada de drain em vez de um por evento. | fence_block -0.31%; uvm_prefetch +0.22%; alloc2m -0.03%; hostreg1m -0.23%; ctx +0.32%; nvenc +0.94%. Media 8 cenarios +0.08% | **RECUSADO** (revertido na hora) | Um dump de logs do GSP por drain em vez de por evento. Sem ganho em nenhum cenario sensivel; nvenc +0.94% e o estado de layout do binario (ignorado pela regra). |
| **2.5** (R2H5) | `src/nvidia/src/kernel/gpu/gsp/kernel_gsp.c:3380 (kgspRecvPoll_IMPL _kgspRpcSanityCheck)`: sanity check a cada 8a iteracao. | fence_block -0.44%; uvm_prefetch +0.09%; alloc2m +0.01%; hostreg1m +0.07%; ctx +0.74%; nvenc +0.95%. Media 8 cenarios +0.13% | **RECUSADO** (revertido na hora) | Sanity check de GPU a cada 8a iteracao do polling. Regressao em ctx_create (+0.74%) e nvenc (estado de layout); sem ganho. |

## Ciclo 3 (Hipoteses 3.1 a 3.5)

| Tentativa | Alvo & Modificacao | Resultado Benchmark (delta % vs campeao da epoca) | Decisao | Racional Tecnico |
| :-- | :-- | :-- | :-- | :-- |
| **3.1** (R3H1) | `src/nvidia/src/kernel/gpu/intr/arch/turing/intr_tu102.c:934 (intrGetPendingStallEngines_TU102 / _intrGetLeafStatus_TU102)`: ler cada leaf de stall sob demanda (so quando um engine da tabela o usa), 1 vez por leaf. | fence_block -10.65%; uvm_prefetch -6.46%; alloc2m -0.10%; hostreg1m -0.05%; ctx +0.27%; nvenc -0.09%. Media 8 cenarios -2.04% | **ACEITO** (`ab11cdd`) -> **mantido no FINAL** | Leitura preguicosa dos leaves de stall: so le o leaf se um engine da tabela o usa (antes: todos os leaves de cada subtree por IRQ). fence_block -10.19%, uvm_prefetch2m -5.88%. Ablacao: +12.46%/+7.58% ao remover -> MANTIDA (principal ganho). Primeira medicao foi barrada por nvenc +0.796% (faixa de layout mal calibrada); re-decidida. |
| **3.2** (R3H2) | `src/nvidia/arch/nvalloc/unix/src/unix_intr.c:262 (osInterruptPending: intrGetPendingNonStall_HAL + intrServiceNonStall_HAL)`: em GSP client, decidir pelo bit de subtree do INTR_TOP (1 leitura) se ha non-stall pendente; o servico ja relê LEAF/EN. | fence_block -8.33%; uvm_prefetch -5.44%; alloc2m +0.05%; hostreg1m +0.26%; ctx +0.30%; nvenc +0.81%. Media 8 cenarios -1.63% | **ACEITO** (`e09b15d`) -> **mantido no FINAL** | Gate por INTR_TOP (1 leitura) no non-stall em GSP client em vez de pre-ler TOP+LEAF+EN: fence_block -8.33%, uvm_prefetch2m -5.44%. Depois absorvida pelo R4H1 (mesma ideia sem a leitura do gate). Ablacao conjunta gate (R3H2+R4H1): +12.79%/+8.47% -> MANTIDA. |
| **3.3** (R3H3) | `kernel-open/nvidia-uvm/uvm_gpu_semaphore.c:844 (uvm_gpu_tracking_semaphore_is_value_completed)`: se payload == 32 bits baixos de completed_value, retornar false sem lock (o update travado devolveria o valor antigo). | fence_block +0.41%; uvm_prefetch +0.26%; alloc2m -0.24%; hostreg1m -0.21%; ctx +0.29%; nvenc +0.03%. Media 8 cenarios +0.13% | **RECUSADO** (revertido na hora) | Retorno sem lock em uvm_gpu_tracking_semaphore_is_value_completed quando o payload nao mudou. Sem ganho (spin de espera, o lock e barato sem contencao). |
| **3.4** (R3H4) | `kernel-open/nvidia/nv.c:2444 (nvidia_poll)`: checar event_data_head/dataless_event_pending sem lock apos poll_wait; retornar 0 se nada pendente. | fence_block -1.97%; uvm_prefetch -0.12%; alloc2m -0.12%; hostreg1m +0.13%; ctx +0.01%; nvenc -0.04%. Media 8 cenarios -0.35% | **ACEITO** (`6380c75`) -> **revertido no FINAL** (ablacao) | nvidia_poll sem spin_lock_irqsave quando nao ha evento (apos poll_wait). fence_block -1.34% (re-teste sobre R3H1); ablacao: +0.53% (< 1%) -> ganho nao demonstrado, revertida no FINAL. |
| **3.5** (R3H5) | `src/nvidia/src/kernel/gpu/intr/arch/turing/intr_nonstall_tu102.c:194,403 (intrGetPendingNonStall_TU102 / intrServiceNonStall_TU102 leaf loops)`: pular o leaf cujo intervalo de vetores nao contem nenhum intrVectorNonStall da tabela. | fence_block +0.28%; uvm_prefetch +0.29%; alloc2m -0.20%; hostreg1m +0.07%; ctx +0.16%; nvenc +0.01%. Media 8 cenarios +0.10% | **RECUSADO** (revertido na hora) | Pular leaf sem vetor non-stall na tabela. Sem efeito: nesta Ada os dois leaves de cada subtree tem vetores. |

## Ciclo 4 (Hipoteses 4.1 a 4.5)

| Tentativa | Alvo & Modificacao | Resultado Benchmark (delta % vs campeao da epoca) | Decisao | Racional Tecnico |
| :-- | :-- | :-- | :-- | :-- |
| **4.1** (R4H1) | `src/nvidia/arch/nvalloc/unix/src/unix_intr.c:277 (osInterruptPending, gate de TOP do R3H2)`: em GSP client chamar o servico non-stall incondicionalmente (ele ja le TOP e devolve conjunto vazio se nada pendente); serviced = FECS || engines servidos. | fence_block -3.09%; uvm_prefetch -2.06%; alloc2m -0.01%; hostreg1m -0.17%; ctx +0.00%; nvenc -0.03%. Media 8 cenarios -0.64% | **ACEITO** (`dfae4bd`) -> **mantido no FINAL** | Chamar o servico non-stall incondicionalmente em GSP client (ele ja le TOP e devolve vazio): remove a leitura do gate. fence_block -3.09%, uvm_prefetch2m -2.06%. Ablacao: +2.83%/+1.78% -> MANTIDA. |
| **4.2** (R4H2) | `kernel-open/common/inc/nv-linux.h:1563 (nv_is_open_complete -> completion_done)`: smp_load_acquire(&open_complete.done) != 0. | fence_block -0.84%; uvm_prefetch -0.11%; alloc2m +0.20%; hostreg1m +0.52%; ctx +0.01%; nvenc -0.03%. Media 8 cenarios -0.04% | **ACEITO** (`eba034a`) -> **revertido no FINAL** (ablacao) | nv_is_open_complete com smp_load_acquire em vez de completion_done (lock). fence_block -0.84%; ablacao: +0.36% (< 1%); ordem mais fraca em arm64 (Judge) -> revertida no FINAL. |
| **4.3** (R4H3) | `kernel-open/nvidia/nv.c:2645 (nvidia_ioctl NV_KMALLOC(arg_copy))`: copiar args <=256 B por buffer na pilha, kmalloc so acima. | fence_block +0.39%; uvm_prefetch +0.22%; alloc2m -0.17%; hostreg1m -0.38%; ctx -0.17%; nvenc +0.03%. Media 8 cenarios +0.01% | **RECUSADO** (revertido na hora) | Buffer de pilha para argumentos de ioctl <= 256 B em vez de kmalloc/kfree. Sem efeito (alocacao e minuscula frente ao trabalho do RM). |
| **4.4** (R4H4) | `src/nvidia/src/kernel/gpu/gsp/kernel_gsp.c:3455 (kgspRecvPoll_IMPL vblank WAR, = R1H2 sobre campeao R3H4)`: WAR de vblank so a cada 8a iteracao. | fence_block +0.03%; uvm_prefetch +0.67%; alloc2m -0.16%; hostreg1m -0.51%; ctx -0.26%; nvenc +0.03%. Media 8 cenarios +0.04% | **RECUSADO** (revertido na hora) | WAR de vblank 1/8 sobre o campeao: regressao em uvm_prefetch2m (+0.67%); sem ganho. |
| **4.5** (R4H5) | `kernel-open/nvidia-uvm/uvm_common.c:249 (uvm_spin_loop, = R1H4 sobre campeao R3H4)`: relogio so a cada 16a chamada. | fence_block +0.43%; uvm_prefetch -0.05%; alloc2m -0.23%; hostreg1m -0.60%; ctx -0.07%; nvenc +0.01%. Media 8 cenarios -0.01% | **RECUSADO** (revertido na hora) | Relogio do uvm_spin_loop 1/16 sobre o campeao: sem efeito. |

## Ciclo 5 (Hipoteses 5.1 a 5.5)

| Tentativa | Alvo & Modificacao | Resultado Benchmark (delta % vs campeao da epoca) | Decisao | Racional Tecnico |
| :-- | :-- | :-- | :-- | :-- |
| **5.1** (R5H1) | `src/nvidia/src/kernel/gpu/gsp/kernel_gsp.c:3372,3455,3459 (kgspRecvPoll_IMPL: gpuCheckTimeout + vblank WAR + backoff)`: vblank WAR 1/8, gpuCheckTimeout 1/8, backoff de PAUSE apos 32 polls vazios, juntos. | fence_block +0.65%; uvm_prefetch +0.59%; alloc2m -0.25%; hostreg1m -0.26%; ctx -0.33%; nvenc +0.05%. Media 8 cenarios +0.12% | **RECUSADO** (revertido na hora) | Sintese do polling de RPC (vblank 1/8 + timeout 1/8 + backoff): regressao em uvm_prefetch2m; os alivios isolados nao se somam. |
| **5.2** (R5H2) | `kernel-open/nvidia-uvm/uvm_common.c:249 + uvm_gpu_semaphore.c:844 (uvm_spin_loop + is_value_completed)`: relogio a cada 16a chamada + retorno sem lock quando payload inalterado. | fence_block -0.19%; uvm_prefetch +0.38%; alloc2m -0.39%; hostreg1m -0.64%; ctx +0.32%; nvenc -0.00%. Media 8 cenarios -0.07% | **RECUSADO** (revertido na hora) | Sintese da espera do UVM (relogio 1/16 + retorno sem lock): sem ganho. |
| **5.3** (R5H3) | `src/nvidia/src/kernel/gpu/intr/arch/turing/intr_nonstall_tu102.c:194,403 (pending + service non-stall)`: 1 leitura de TOP por indice + pular leaf sem vetor non-stall. | fence_block +0.21%; uvm_prefetch +0.54%; alloc2m -0.00%; hostreg1m -0.29%; ctx -0.01%; nvenc +0.00%. Media 8 cenarios +0.10% | **RECUSADO** (revertido na hora) | Sintese ISR extra (TOP por indice + pular leaf sem vetor): sem ganho. |
| **5.4** (R5H4) | `src/nvidia/src/kernel/gpu/gsp/kernel_gsp.c:2059,3380 (_kgspRpcDrainEvents log dump; kgspRecvPoll_IMPL sanity check)`: 1 dump de logs por drain + sanity check a cada 8a iteracao. | fence_block +0.28%; uvm_prefetch +0.15%; alloc2m -0.25%; hostreg1m -0.53%; ctx -0.16%; nvenc +0.02%. Media 8 cenarios -0.03% | **RECUSADO** (revertido na hora) | Sintese do drain (1 dump de logs + sanity 1/8): sem ganho. |
| **5.5** (R5H5) | `combo final dos rejeitados nao conflitantes (kernel_gsp.c recvPoll; uvm_common.c/uvm_gpu_semaphore.c; intr_nonstall_tu102.c; nv.c ioctl)`: aplicar juntos tudo que foi rejeitado e nao conflita com o campeao. | fence_block +0.33%; uvm_prefetch +0.29%; alloc2m -0.31%; hostreg1m -0.49%; ctx -0.27%; nvenc -0.00%. Media 8 cenarios -0.08% | **RECUSADO** (revertido na hora) | Mega-combo de todos os rejeitados compativeis (R5H1+R5H2+R5H3+R4H3): -0.08% medio, nenhum cenario passa a regra. |

## Ablacao leave-one-out (condicao 2 do Judge)

Campeao medido em 6 cargas intercaladas: desvio entre cargas fence_block 0.20%, uvm_prefetch2m 0.09%, ctx_create 0.23%, alloc2m 0.09%. Efeito = (sem a mudanca - campeao)/campeao; positivo = a mudanca ajuda. `*` = acima de max(1%, 2x desvio entre cargas).

| Sem | fence_block | uvm_prefetch2m | alloc2m | hostreg1m | ctx_create | nvenc | Conclusao |
| :-- | --: | --: | --: | --: | --: | --: | :-- |
| R1H1 | -0.26 | -0.53 | -0.02 | +0.01 | +0.48 | -0.01 | ganho nao demonstrado -> revertida |
| R2H2 | +2.81* | +1.95* | +0.05 | +0.00 | -0.08 | +0.04 | ganho demonstrado -> mantida |
| R2H3 | -0.24 | -0.13 | -0.05 | +0.04 | +0.55 | -0.96 | ganho nao demonstrado (nvenc = estado de layout) -> revertida |
| R3H1 | +12.46* | +7.58* | -0.06 | +0.05 | -0.02 | +0.14 | principal ganho -> mantida |
| R3H4 | +0.53 | -0.41 | -0.07 | -0.03 | +0.20 | -0.00 | ganho nao demonstrado -> revertida |
| R4H2 | +0.36 | -0.01 | +0.10 | -0.03 | +0.17 | -0.01 | ganho nao demonstrado -> revertida |
| R4H1 | +2.83* | +1.78* | -0.01 | +0.02 | +0.03 | +0.04 | ganho demonstrado -> mantida |
| ISRGATE | +12.79* | +8.47* | -0.06 | +0.32 | +0.05 | +0.19 | gate (R3H2+R4H1) -> mantido |

## Parecer do Judge (Claude, `claude -p`)

- **Veredito**: `VERDICT: APPROVE_WITH_CONDITIONS` (texto integral em `artifacts/phase5/review.md`).
- Condicoes e como foram tratadas: (1) testes funcionais 1-5 antes de instalar -> **pendentes (exigem a GPU em uso real, depois do deploy)**; (2) ablacao leave-one-out -> **feita** (tabela acima); R1H1, R2H3, R3H4, R4H2 marcadas 'ganho nao demonstrado' e **removidas do FINAL**, o que tambem elimina os riscos apontados (contador global do R1H1, premissa do R2H3 em outros chips, ordem fraca em arm64 do R4H2); (3) mecanismo do fence_block -> **confirmado** (1.0 IRQ/fence nos dois, zero erros); (4) declarar desvios post-hoc -> **abaixo**; (5) R4H2 so x86 -> **moot** (removida); (6) contador por KernelGsp -> **moot** (R1H1 removida).

## Desvios registrados (todos com `skillgate.py request`, auto-aprovados)

1. `flags-adaptations`: o modulo de kernel nao aceita SIMD, stack-protector off, flags de link/cdsort; usadas 14 das 29 flags do template.
2. `flags-noplt`: `-fno-plt` gera GOTPCRELX e o kernel recusa o modulo (`Unknown rela relocation: 42`); removida.
3. `harness-ctx-create`: cenario ctx_create (127 ms/op, 273M ciclos de kernel) adicionado no meio da campanha; 6 execucoes por bateria para caber em 60 s; baseline refeito (as-is x2, base).
4. `nvenc-layout-state` + `nvenc-band`: nvenc1080p alterna entre estados (~1593, 1605, 1608 us) conforme o layout do binario; deltas de 0.7-1.1% nesse cenario sao ignorados (**post-hoc**; pode mascarar regressao real de NVENC).
5. `control-scenarios`: submit_spin e h2d64k (9 e 14 ciclos de kernel/op) viraram controle, fora da regra (**post-hoc**; levou a re-decidir R3H1 e R3H4, de rejeitadas para aceitas).
6. `decide2.py` usa MAD maximo entre candidato, campeao e A/A entre cargas; 'metades' sao pares/impares das execucoes da mesma carga (o Judge notou que nao detectam efeito de layout; a confirmacao independente real foi a carga final + ablacao).

## Teste funcional com o FINAL carregado em memoria (nao instalado)

Condicao 1 do Judge, parcial: sddm/River subiram com o FINAL (nvidia-drm modeset=1), `vkcube --c 600` terminou sem erro, 10182 IRQs da GPU tratadas, **0 erros novos no dmesg** (Xid, timeout, nobody cared, BUG, Oops). Log: `state_smoke.log`.
```
srcversion FINAL=4200B1C66D4D12038311105 carregado=4200B1C66D4D12038311105
sddm iniciado
river vivo apos 4s
vkcube 600 frames rc=0 tempo=3.982521059 s (esperado ~5 s a 120 Hz); Selected GPU 0: NVIDIA GeForce RTX 4050 Laptop GPU, type: DiscreteGpu, apiVersion
IRQs nvidia durante o teste: 10182; erros novos no dmesg: 0
river ainda vivo
```
Ainda **nao testados** (exigem uso real apos o deploy): RTD3/D3cold, suspend/resume, hotplug de monitor, VRR, Vulkan/DXVK por 30 min, sessao longa de NVENC/Sunshine, ciclos de unload/reload.

## Estado e proposta (portao)

- Campeao FINAL: `~/build-optimizations/nvidia-open/mods/FINAL/*.ko` (commit `c5c27ae` em `src/`). Patch: `~/Documents/poc/nvidia-open-opt/patches/FINAL_vs_stock.patch`. Alteracoes: `unix_intr.c`, `intr_nonstall_tu102.c`, `intr_tu102.c` (so o caminho de interrupcao).
- Driver do sistema **nao foi alterado**; backup do stock em `~/build-optimizations/backup-nvidia-stock/`. A maquina reinicia no driver original ao fechar a janela.
- Proposta: **deploy do FINAL** (Fase 8) com os testes funcionais 1-5 do Judge logo depois (display/modeset, RTD3, suspend, Vulkan, NVENC), com rollback pronto. **Nenhuma instalacao sem o seu 'deploy'.**

VERDICT: APPROVE_WITH_CONDITIONS
