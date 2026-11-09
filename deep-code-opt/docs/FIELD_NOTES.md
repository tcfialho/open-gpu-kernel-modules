# Notas de campo: o que não era óbvio até construir o meio de teste

Tudo aqui custou tempo. Ordem aproximada de descoberta.

## 1. Para trocar o `nvidia.ko` a GPU precisa estar livre
`rmmod nvidia` falha se qualquer processo segura `/dev/nvidia*` ou `/dev/dri/*`. Na máquina isso inclui **sddm, River, Sunshine, Xwayland, kitty, maindeck-bar/wm, lactd, nvidia-powerd, nvidia-persistenced**.
- Ordem: parar `sunshine-after-login` (user) → `sunshine-prelogin` → `sddm` → `lactd/nvidia-powerd/nvidia-persistenced` → matar holders restantes (`fuser`, SIGTERM; SIGKILL só a partir da 3ª volta) → `rmmod nvidia_drm nvidia_uvm nvidia_modeset nvidia` (essa ordem).
- Resultado: **tela preta e sem teclado** enquanto a janela está aberta. Não há compositor, então não há nada para receber input. Por isso tudo é autônomo.
- `window/window.sh enter` faz isso. `bench/swap.sh <dir>` troca o conjunto de módulos (`insmod` com `NVreg_InitializeSystemMemoryAllocations=0 NVreg_EnableGpuFirmware=1 NVreg_DynamicPowerManagement=0x00`, `modeset=1` no drm, `nvidia-smi -lgc 1500,1500`).

## 2. Voltar sozinho se algo travar (watchdog)
Módulo experimental pode travar a máquina com a tela apagada. `window.sh` seta `kernel.panic_on_oops=1 panic=10 softlockup_panic=1 hung_task_panic=1 hung_task_timeout_secs=120`: qualquer oops/travamento vira reboot em 10 s no driver instalado. Restaurar com `sysctl -q --system`.
O Caps Lock pisca (`/sys/class/leds/*::capslock`) como sinal de vida com a tela apagada.

## 3. Login automático e agente que sobrevive à tela apagada
Para o agente (Claude) continuar sem teclado e sem tela:
- `window/enable.sh`: `/etc/sddm.conf` com `[Autologin] User=... Session=river.desktop`; entrada padrão do Limine = boot com HDMI virtual 120 Hz; `loginctl enable-linger`; unit `systemd --user` `nvopt-agent.service`. Tudo com backup `*.nvopt-backup`.
- **O agente tem que viver fora da sessão do sddm**: parar o sddm mata tudo que está na sessão. `window/agent.sh` roda o Claude num `tmux -L claude-nv` iniciado pela unit de usuário (linger), `claude --resume <SESSION_ID>`. A unit usa um `flock` para não ter dois agentes, e `HANDOFF_PID` para não rodar duas instâncias da mesma conversa.
- `window.sh` aborta se o tmux estiver dentro de um `session-*.scope` (seria morto junto).
- `ENABLED`/`MISSION_DONE` são flags de arquivo; `window/finalize_nokill.sh` encerra **sem** reboot e **sem** matar o tmux (o `cleanup.sh` original reiniciava a máquina).
- Desfazer: `window/cleanup.sh` / `finalize_nokill.sh` restauram sddm.conf, limine.conf, river/init e desabilitam a unit.

## 4. A tela piscando (a parte mais cara)
Sintoma: barra (maindeck-bar) piscando em loop, sem conseguir abrir terminal; foi preciso reiniciar.
Cadeia confirmada nos logs:
1. Qualquer troca de modo da tela (`wlr-randr`, `sunshine-display-normal`, cliente Sunshine conectando) remove e recria os `wl_output` (`global_remove` / `global` no `river.log`).
2. `maindeck-bar` sai com status 0 quando o output some; o laço do `river/init` o religa em 1 s: **uma piscada**.
3. Se algo derruba/religa isso em ciclo, vira loop. Dois causadores reais:
   - **Sunshine em crash loop** (SIGABRT a cada ~22 s): o `ExecStopPost` rodava `wlr-randr` + reset de clocks, forçando mudança de modo a cada volta. Hipótese (agy) para o crash: falta de `qt6-wayland` (Qt caía no fallback X11). Instalei o pacote; **não houve teste A/B**, o Sunshine só ficou estável depois.
   - **Sessão gráfica antiga viva**: parar o sddm não mata os laços do `river/init` (maindeck-wm/bar, mako). No login seguinte a sessão velha e a nova disputam `bar.log` e o Wayland. **Correção:** antes de apagar a tela, `loginctl terminate-session <id>` nas sessões `Type=wayland` do usuário (está em `scripts/mn_run.sh`).
4. `kill -9` às cegas nos holders piorou. Só SIGKILL depois de duas tentativas com SIGTERM.
5. `mako` entra em `start-limit-hit` enquanto não há compositor (ruído no journal, inofensivo).

Também: o `sunshine-prelogin` (tela de login) e o `sunshine-after-login` brigam; durante a janela o prelogin é mascarado (`systemctl mask --runtime`) e desmascarado depois.

## 5. Flags que o kernel recusa (módulo ≠ biblioteca)
Das 29 flags do template só ~14 se aplicam a módulo de kernel.
- `-mavx2 -mfma` e SIMD: proibido (Kbuild força `-mno-sse -mno-avx`; usar corromperia registradores do espaço de usuário). `-mtune=native` ok.
- `-fno-plt`: gera `R_X86_64_REX_GOTPCRELX`; o loader do kernel responde **`module: nvidia: Unknown rela relocation: 42`**. Removida.
- **`-march=native` sem SIMD funciona** (BMI/popcnt/lzcnt etc., zero xmm/ymm/zmm no `.ko`), mas o ThinLTO passou a gerar GOTPCRELX em `gmcapiDispatch` (handlers `weak` de `gmcapi_impl.c`). Solução: `-fno-lto` só nesse arquivo (`src/nvidia/Makefile`). `-fdirect-access-external-data` **não** resolveu.
- Verificar sempre: `readelf -rW x.ko | grep -c GOTPCRELX` deve ser 0; `objdump -d x.ko | grep -cE '%[xyz]mm'` deve ser 0; `modinfo -F vermagic` igual a `uname -r`.
- Debug info completo é obrigatório (BTF de módulo); `-gline-tables-only` quebra. Kernel tem IBT, ORC, retpoline e `-mfunction-return=thunk-extern`.
- Flags de link (`cdsort`, `--emit-relocs`) não se aplicam: `.ko` é `ld.lld -r`.

## 6. Medir: armadilhas do `perf`
- `cycles:k` só conta kernel. O perfil do processo inteiro mostra a **inicialização** do CUDA/NVENC. Perfilar só o laço medido com `perf record --control fd:` (`bench/prof_loop.sh`, `harness2_prof.cu` com `perf_ctl`).
- `kprobe` em símbolos de módulo retornou `EINVAL`; contar RPCs por esse caminho foi abandonado.
- `submit_spin` e `h2d64k` não passam pelo módulo; servem de controle.
- `nvenc1080p` alterna entre estados (~1593 / 1605 / 1608 µs) conforme o layout do binário: ver faixa ignorada em `decide2.py`.
- Um único binário campeão precisa de **várias cargas** para medir ruído entre recargas (desvio 0,1–0,25%).

## 7. Onde estava o ganho
O hot path era `rm_isr → osInterruptPending → intrServiceNonStall_TU102 / intrGetPendingNonStall_TU102 / intrGetPendingStallEngines_TU102`. Cada leitura MMIO PCIe custa ~0,6 µs e a ISR relia os mesmos registradores várias vezes por interrupção. Polling de RPC (`kgspRecvPoll`) e espera do UVM são limitados pelo tempo do GSP/GPU: nada de CPU ali ajudou.
Na Ada, `PDB_PROP_INTR_READ_ONLY_EVEN_NUMBERED_INTR_LEAF_REGS` é só Turing (falso aqui).

## 8. Fonte "stock" ≠ tag upstream
O baseline da máquina tinha patches de pacote (`dkms.conf` na raiz, `DATE` reprodutível no `utils.mk`, `nvkms-flip.c`). Estão no commit `packaging:` sobre a tag `615.78.08`. Sem ele o "as-is" não reproduz o driver instalado.

## 9. Deploy
`.ko.zst` em `/lib/modules/$(uname -r)/updates/dkms/`. `scripts/deploy_FINAL.sh`: confere vermagic == `uname -r`, backup dos quatro `.ko.zst` em `/var/backups/nvidia-615.78.08-stock-<data>`, `zstd -19` para `.new`, `mv -f` (atômico) e `depmod -a`. Vale no **próximo boot**. `scripts/rollback_FINAL.sh` restaura. Os `.ko.zst` instalados são conferidos por sha256 contra `mods/<id>/*.ko`.

## 10. O gate da skill
A campanha rodou sob um gate (hooks + `CONTRACT.json`) que obriga fases, artefatos e limites. Aprendizados: aprovação intermediária travou o trabalho (decisão final: só `deploy` pede o usuário; desvios são registrados e seguem); o gate reconhecia só "aprovo/autorizo/pode instalar" e **não** a palavra "deploy" que ele mesmo pedia.

## Pendente
Testes funcionais depois do deploy: RTD3/D3cold, suspend/resume, hotplug de monitor, VRR, Vulkan/DXVK por 30 min, sessão longa de NVENC/Sunshine, ciclos de unload/reload.
