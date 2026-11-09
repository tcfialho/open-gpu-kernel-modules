"""Hipoteses: id -> (descricao, [(arquivo, antigo, novo)]). Aplicar: python3 hyps.py <ID>"""
import sys
OS="src/src/nvidia/arch/nvalloc/unix/src/os.c"; GSP="src/src/nvidia/src/kernel/gpu/gsp/kernel_gsp.c"
UT="src/kernel-open/nvidia-uvm/"; FL="src/.optflags"
BASEFL="-O3 -mtune=raptorlake -falign-functions=32 -falign-loops=16\n"
def flags(extra): return [(FL, BASEFL, BASEFL.rstrip("\n")+" "+extra+"\n")]
def attr(f, sig, a): return [(f, sig, "__attribute__((%s)) %s"%(a,sig))]
H={}
H["R1H1"]=("skip GSP health check (MMIO) quando resposta RPC esperada ja chegou",[("src/src/nvidia/src/kernel/gpu/gsp/kernel_gsp.c","""    // If GSP-RM has died, the GPU will need to be reset
    if (!kgspHealthCheck_HAL(pGpu, pKernelGsp))
        return NV_ERR_RESET_REQUIRED;""","""    // If GSP-RM has died, the GPU will need to be reset.
    // Skipped when the expected RPC response was just received: GSP is demonstrably alive.
    if (nvStatus != NV_WARN_MORE_PROCESSING_REQUIRED && !kgspHealthCheck_HAL(pGpu, pKernelGsp))
        return NV_ERR_RESET_REQUIRED;""")])
H["R1H2"]=("osDevReadReg032: fast-path sem chamada vgpuDevReadReg032 em bare-metal (evita ~5 derefs por leitura MMIO)",
 [(OS,"""    NvU32 retval = 0;
    NvBool vgpuHandled = NV_FALSE;

    retval = vgpuDevReadReg032(pGpu, thisAddress, &vgpuHandled);
    if (vgpuHandled)
    {
        return retval;
    }
""","""    NvU32 retval = 0;
    NvBool vgpuHandled = NV_FALSE;

    {
        OBJHYPERVISOR *pHypervisorFast = SYS_GET_HYPERVISOR(SYS_GET_INSTANCE());
        if (__builtin_expect(pGpu != NULL && (IS_VIRTUAL(pGpu) || (pHypervisorFast && pHypervisorFast->bDetected && pHypervisorFast->bIsHVMGuest)), 0))
        {
            retval = vgpuDevReadReg032(pGpu, thisAddress, &vgpuHandled);
            if (vgpuHandled)
            {
                return retval;
            }
        }
    }
""")])
H["R1H3"]=("osDevWriteReg032: mesmo fast-path bare-metal para escritas MMIO",
 [(OS,"""    NvBool vgpuHandled = NV_FALSE;

    vgpuDevWriteReg032(pGpu, thisAddress, thisValue, &vgpuHandled);
    if (vgpuHandled)
    {
        return;
    }
""","""    NvBool vgpuHandled = NV_FALSE;

    {
        OBJHYPERVISOR *pHypervisorFast = SYS_GET_HYPERVISOR(SYS_GET_INSTANCE());
        if (__builtin_expect(pGpu != NULL && (IS_VIRTUAL(pGpu) || (pHypervisorFast && pHypervisorFast->bDetected && pHypervisorFast->bIsHVMGuest)), 0))
        {
            vgpuDevWriteReg032(pGpu, thisAddress, thisValue, &vgpuHandled);
            if (vgpuHandled)
            {
                return;
            }
        }
    }
""")])
H["R1H4"]=("kgspRecvPoll: WAR de vblank (leitura MMIO de interrupcao) a cada 4 iteracoes do spin em vez de toda iteracao",
 [(GSP,"""            kdispApplyAggressiveVblankHandlingWar(pGpu, pKernelDisplay);
        }
""","""            static NvU32 vblankWarSkip;
            if ((++vblankWarSkip & 3U) == 0U)
                kdispApplyAggressiveVblankHandlingWar(pGpu, pKernelDisplay);
        }
""")])
H["R1H5"]=("_kgspRpcDrainEvents: kgspDumpGspLogs uma vez apos o loop de eventos, nao por evento",
 [(GSP,"""        nvStatus = _kgspRpcDrainOneEvent(pGpu, pRpc, expectedFunc, expectedSequence, rpcHandlerContext,
                                         pConditionFunc, pConditionData);
        kgspDumpGspLogs(pKernelGsp, NV_FALSE);
    }
""","""        nvStatus = _kgspRpcDrainOneEvent(pGpu, pRpc, expectedFunc, expectedSequence, rpcHandlerContext,
                                         pConditionFunc, pConditionData);
    }
    kgspDumpGspLogs(pKernelGsp, NV_FALSE);
""")])
H["R2H1"]=("uvm_range_tree_iter_first: hint de branch (no encontrado e comum nas iteracoes)",
 [(UT+"uvm_range_tree.c","""    node = range_node_find(tree, start, NULL, &next);
    if (node)
        return node;""","""    node = range_node_find(tree, start, NULL, &next);
    if (__builtin_expect(node != NULL, 0))
        return node;""")])
H["R2H2"]=("uvm_range_tree_find: atributo hot",
 attr(UT+"uvm_range_tree.c","uvm_range_tree_node_t *uvm_range_tree_find(uvm_range_tree_t *tree, NvU64 addr)","hot"))
H["R2H3"]=("thread_context_non_interrupt_add: modulo por constante pot2 vira mascara (&7)",
 [(UT+"uvm_thread_context.c","const size_t curr_array_index = i % UVM_THREAD_CONTEXT_ARRAY_SIZE;","const size_t curr_array_index = i & (UVM_THREAD_CONTEXT_ARRAY_SIZE - 1);")])
H["R2H4"]=("uvm_spin_loop: timeout de print como unlikely",
 [(UT+"uvm_common.c","if (curr - spin->print_time_ns >= 1000*1000*1000*UVM_SPIN_LOOP_PRINT_TIMEOUT_SEC) {","if (__builtin_expect(curr - spin->print_time_ns >= 1000*1000*1000*UVM_SPIN_LOOP_PRINT_TIMEOUT_SEC, 0)) {")])
H["R2H5"]=("range_node_find: atributo hot",
 attr(UT+"uvm_range_tree.c","static uvm_range_tree_node_t *range_node_find(uvm_range_tree_t *tree,","hot"))
H["R3H1"]=("flags: -falign-functions=64", flags("-falign-functions=64"))
H["R3H2"]=("flags: -mllvm -inline-threshold=500", flags("-mllvm -inline-threshold=500"))
H["R3H3"]=("flags: -funroll-loops", flags("-funroll-loops"))
H["R3H4"]=("flags: -mllvm -align-all-nofallthru-blocks=5", flags("-mllvm -align-all-nofallthru-blocks=5"))
H["R3H5"]=("flags: -O2 (frente a -O3 do campeao)", [(FL,BASEFL,"-O2 -mtune=raptorlake -falign-functions=32 -falign-loops=16\n")])
H["R4H1"]=("uvm_va_block_service_finish: atributo hot",
 attr(UT+"uvm_va_block.c","NV_STATUS uvm_va_block_service_finish(uvm_processor_id_t processor_id,","hot"))
H["R4H2"]=("msgqRxGetReadBuffer: atributo hot", attr("src/src/nvidia/src/libraries/msgq/msgq.c","msgqRxGetReadBuffer(msgqHandle handle, unsigned n)","hot") if False else
 [("src/src/nvidia/src/libraries/msgq/msgq.c","msgqRxGetReadBuffer(msgqHandle handle, unsigned n)","msgqRxGetReadBuffer(msgqHandle handle, unsigned n) __attribute__((hot))")])
H["R4H3"]=("flags: -mbranches-within-32B-boundaries", flags("-mbranches-within-32B-boundaries"))
H["R4H4"]=("flags: -fno-jump-tables", flags("-fno-jump-tables"))
H["R4H5"]=("flags: -mllvm -x86-pad-for-align=false -mllvm -x86-align-branch-boundary=0 (sem padding de alinhamento)", flags("-mllvm -x86-pad-for-align=false"))
H["R5H1"]=("flags: -falign-loops=32", [(FL,"-falign-loops=16","-falign-loops=32")])
H["R5H2"]=("flags: -mtune=alderlake", [(FL,"-mtune=raptorlake","-mtune=alderlake")])
H["R5H3"]=("flags: -mllvm -enable-misched=false", flags("-mllvm -enable-misched=false"))
H["R5H4"]=("flags: -mllvm -unroll-threshold=300", flags("-mllvm -unroll-threshold=300"))
H["R5H5"]=("flags: -fno-stack-clash-protection -fcf-protection=none", flags("-fno-stack-clash-protection -fcf-protection=none"))
if __name__=="__main__":
    d,ed=H[sys.argv[1]]
    for f,a,b in ed:
        s=open(f).read(); assert s.count(a)==1,(f,a[:60],s.count(a)); open(f,"w").write(s.replace(a,b))
    print(d)
