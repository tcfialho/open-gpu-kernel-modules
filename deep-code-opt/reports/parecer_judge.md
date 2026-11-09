# Fase 5 — Revisão crítica do Judge (Claude, claude-opus-5-5)

Escopo: diff consolidado base → campeão (8 hipóteses) do driver NVIDIA open 615.78.08, mais a metodologia. Cada mudança foi conferida no código-fonte do campeão e no kernel 7.3.

## 1. Corretude e riscos de cada mudança

### R1H1 — health check do GSP só a cada 16º ciclo vazio (`kernel_gsp.c` `_kgspRpcDrainEvents`)
- **Semântica:** correta. Quando um ciclo trata evento, recebe a resposta esperada ou dá erro, o check continua rodando sempre.
- **Rede de segurança existe:**
  - check periódico de 1 Hz (`_kgspHealthPeriodicHealthCheck`, `kernel_gsp.c:2483`);
  - `kgspService_TU102` (`kernel_gsp_tu102.c:1027`) no interrupt do GSP;
  - `message_queue_cpu.c:404`;
  - `_kgspRpcSanityCheck` a cada iteração do poll de RPC.
- **Efeito de um crash do GSP:** a detecção atrasa no máximo 15 iterações. Aceitável.
- **Defeito:** `static NvU32 emptyDrainCount` é global para todas as GPUs e o incremento não é atômico.
  - Com várias GPUs alternando, a paridade do contador pode deixar uma GPU sem nunca cair no `&0xF==0`. Ela fica só com o check de 1 Hz.
  - Corrida benigna, mas o KCSAN reclama.
  - Correção: campo por `KernelGsp`.
  - Impacto nulo com 1 GPU.
- **Não testado:** o caminho de erro (crash do GSP, Xid 120).

### R2H2 — ler EN_SET só se LEAF != 0 (`intr_nonstall_tu102.c`)
- **Semântica:** puramente algébrica. Ler EN_SET não tem efeito colateral, em PF ou em VF. Sem risco.
- **Código morto:** com o R4H1, `intrGetPendingNonStall_TU102` não roda mais em GSP client. Só a parte em `intrServiceNonStall_TU102` tem efeito nesta máquina.
- **Consequência:** o ganho atribuído ao R2H2 quando foi aceito não vale mais integralmente.

### R2H3 — cache de `ceFaultMethodBufferSize` (`gpu.c:6292`)
- **Semântica:** o campo só é lido e é zero desde o init. O valor vem do RPC `NV2080_CTRL_CMD_CE_GET_FAULT_METHOD_BUFFER_SIZE` (físico, firmware fechado). Num VF SR-IOV vem do VSI estático.
- **Riscos residuais:**
  - (a) Se o GSP calcular o tamanho a partir do mapeamento PCE/LCE (`ceUpdatePceLceMappings`) ou do MIG/CC (Hopper+), o cache guarda um valor velho. Na Ada isso não se aplica; em outros chips é premissa não verificada.
  - (b) O `pGpu` persiste no suspend/resume e no reset por recuperação. O valor velho só é problema se a premissa (a) cair.
  - (c) Escrita sem lock, idempotente: benigna.
- **Defeito anterior, não piorado:** retorna `NV_OK` mesmo quando falha e deixa `*size` sem inicializar.

### R4H1 — serviço non-stall incondicional em GSP client (`unix_intr.c` `osInterruptPending`)
- **Equivalência:** `intrServiceNonStall_TU102` lê o INTR_TOP de cada subtree, pula o subtree sem pending e monta `pEngines` com o mesmo critério do GetPending. `*serviced` é equivalente: FECS fica salvo em `bFecsPending` antes do `bitVectorClrAll` interno.
- **Guardas cobertas:**
  - o GetPending tinha o early-return de `IS_GPU_GC6_STATE_ENTERED` e o Service não tem; o gate novo cobre isso;
  - `!IS_VIRTUAL` cobre `IS_VIRTUAL_WITHOUT_SRIOV`.
- **Diferença de comportamento:** com `!API_GPU_ATTACHED_SANITY_CHECK` ou `API_GPU_IN_RESET_SANITY_CHECK`, o Service devolve `pEngines` vazio.
  - Antes, `*serviced=TRUE`; agora pode ser FALSE, `rm_isr` retorna `NV_ERR_NO_INTR_PENDING` e isso vira IRQ_NONE.
  - Com MSI não trava. Com INTx compartilhado durante reset, conta para o "nobody cared".
  - Risco baixo, não testado.
- **Interrupt perdido:** nenhum novo. Leaf pendente sem entrada na tabela não era limpo antes nem agora.
- **GC6/RTD3:** a janela de corrida com a ISR lockless é a mesma de antes.
- **Escopo:** Tegra/SoC display e vGPU guest ficam fora desse ramo ou no `else`, inalterado.

### R3H1 — leitura preguiçosa dos leaves de stall (`intr_tu102.c` `intrGetPendingStallEngines_TU102`)
- **Equivalência com o original:**
  - `leafIndex = vector/32` com `NV_MAX_INTR_LEAVES=16`, então `NVBIT` em 32 bits está em faixa;
  - leaf ímpar com `bEvenLeavesOnly` fica em 0 pelo memset, igual ao original;
  - cache do leaf 4 aplicado sempre: equivalente, porque o sanity check exige o leaf na máscara stall legada.
- **Diferença:** a leitura fica intercalada com a iteração em vez de um snapshot. Um leaf lido depois pode ver um bit novo. Inócuo, porque o bottom half relê.
- **Cobertura de chips:** só vale para os chips cujo HAL mapeia `_TU102` (Turing–Ada). Blackwell não foi auditado.
- **Teste que falta:** vblank (DISP via leaf 4 em cache) exige teste de display.

### R3H4 — `nvidia_poll` sem lock quando não há nada pendente (`nv.c`)
- **Wakeup:** correto. `poll_wait` (com o lock da waitqueue) vem antes do `READ_ONCE`. O produtor (`nv.c:4230-4265`) escreve sob `fp_lock` e chama `wake_up_interruptible` incondicional, que pega o lock da waitqueue. Garante happens-before e não perde wakeup.
- **O que não muda:** O_NONBLOCK continua sem poll_wait, como no original; o caso pendente continua limpando `dataless_event_pending` sob o lock.

### R4H2 — `nv_is_open_complete` com `smp_load_acquire` (`nv-linux.h`)
- **Corretude:** correta no x86 (TSO).
- **Ordem mais fraca que o original:** `completion_done` (kernel 7.3, `completion.c:342`) faz lock/unlock de `wait.lock` depois de ver `done`. Isso sincroniza com o unlock de `complete_all`.
- **No arm64 (Grace/Tegra):** `done` é um store simples sob lock, sem release próprio. O acquire não garante ver `nvptr`/`open_rc` gravados antes do `complete_all`. Resultado possível: POLLERR espúrio.
- **Acoplamento:** depende do layout interno de `struct completion` (`unsigned int done`).
- **Ganho:** marginal, só um lock irqsave sem contenção.

## 2. Falhas de metodologia

1. **Referência e campeão medidos em uma carga só.** O MAD é calculado dentro da carga e ignora a variância entre cargas (layout do módulo, estado do GSP, clocks). O nvenc bimodal em ~0,8–0,95% conforme o layout prova que essa variância existe. Por isso, deltas aceitos abaixo de ~1% (alloc2m −0,59%, ctx_create −0,55%, nvenc −0,37%, hostreg1m −0,21%) não se distinguem de efeito de layout. Só fence_block (−25,8%) e uvm_prefetch2m (−16,5%) são robustos.
2. **"Metades independentes" não são independentes:** mesma carga, mesmo binário, mesmo estado térmico. Não detectam o efeito de layout.
3. **Mudanças de regra post-hoc:**
   - controles removidos da regra e janela do nvenc criada depois de ver os dados;
   - só R3H1 e R3H4 foram retestadas;
   - rejeições anteriores causadas por "regressão" em controle ou nvenc podem ser falsos negativos;
   - o viés é assimétrico.
4. **Janela de exclusão do nvenc [0,7; 1,1]%:** mascara regressão real no cenário NVENC/Sunshine. Correção: rodadas intercaladas A/B/A/B com recarga, ou fixar o layout antes de medir.
5. **Atribuição cumulativa sem ablação:** o R4H1 substituiu o R3H2 e o R2H2 virou parcialmente código morto. Não se sabe quais mudanças produzem os −25,8%. Falta leave-one-out para R4H2, R3H4, R2H3 e R2H2 (ganho pequeno) e para R1H1, R4H1 e R3H1 (trazem risco).
6. **Comparações múltiplas:** 25 hipóteses × ~7 métricas com limiar 2×MAD, sem correção.
7. **Afinidade e clock não declarados:** a afinidade da IRQ da GPU não foi fixada (ISR em P-core ou E-core, C-states) e governor/turbo e clock da GPU não foram declarados.
8. **Mecanismo do fence_block não confirmado:** faltam IRQs por fence (`/proc/interrupts`), zero timeouts de semáforo e leituras MMIO por ISR antes/depois.
9. **Cobertura funcional das ~30 cargas:** só compute/UVM; nada de display, suspend, RTD3 ou crash do GSP.

## 3. Testes funcionais antes de instalar (em ordem)

1. **RTD3 / D3cold (notebook híbrido):** ciclos D3 → wake por app; dmesg sem "nobody cared" e sem Xid. Exercita o gate GC6 do R4H1.
2. **Display/modeset na dGPU:** vblank/page-flip, VRR, multi-monitor, hotplug DP/HDMI, PRIME offload (R3H1, leaf 4).
3. **Suspend/resume:** s2idle/S3 com os serviços nvidia-suspend/resume e hibernate, mais carga de GPU logo depois.
4. **Vulkan/DXVK pesado em fences por 30 min ou mais:** sem hang nem timeout; contagem de IRQs coerente com a base.
5. **NVENC/Sunshine:** sessão longa, com fps/latência comparados à base.
6. **CUDA/UVM:** muitos processos criando canais (R2H3), fault replay, pollers concorrentes (nvidia-smi, nvtop, persistenced).
7. **Ciclos de unload/reload do módulo.**

## 4. Veredito

VERDICT: APPROVE_WITH_CONDITIONS — (1) passar os testes 1–5 da seção 3 sem Xid/oops/"nobody cared"; (2) rodar ablação leave-one-out com recarga intercalada A/B para R4H2, R3H4, R2H3 e R2H2, e no relatório marcar como "ganho não demonstrado" o que ficar abaixo de ~1%; (3) confirmar o mecanismo do fence_block (IRQs por fence iguais, zero timeouts); (4) declarar no relatório o desvio post-hoc (controles e janela do nvenc) e o piso de ruído entre cargas; (5) R4H2 só vale para x86 — registrar a premissa; (6) recomendado, não bloqueante para 1 GPU: `emptyDrainCount` por `KernelGsp`.
