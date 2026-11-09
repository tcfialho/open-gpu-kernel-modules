from _lib import patch
patch("src/nvidia/src/kernel/gpu/gsp/kernel_gsp.c", [
("""    NV_STATUS nvStatus = NV_OK;
    OBJRPC *pRpc = GPU_GET_RPC(pGpu);

    while (nvStatus == NV_OK)
    {
        nvStatus = _kgspRpcDrainOneEvent(pGpu, pRpc, expectedFunc, expectedSequence, rpcHandlerContext,
                                         pConditionFunc, pConditionData);
        kgspDumpGspLogs(pKernelGsp, NV_FALSE);
    }

    // If GSP-RM has died, the GPU will need to be reset
    if (!kgspHealthCheck_HAL(pGpu, pKernelGsp))
        return NV_ERR_RESET_REQUIRED;
""", """    NV_STATUS nvStatus = NV_OK;
    OBJRPC *pRpc = GPU_GET_RPC(pGpu);
    NvU32 nEventsHandled = 0;
    static NvU32 emptyDrainCount;

    while (nvStatus == NV_OK)
    {
        nvStatus = _kgspRpcDrainOneEvent(pGpu, pRpc, expectedFunc, expectedSequence, rpcHandlerContext,
                                         pConditionFunc, pConditionData);
        if (nvStatus == NV_OK)
            nEventsHandled++;
        kgspDumpGspLogs(pKernelGsp, NV_FALSE);
    }

    //
    // The health check costs MMIO reads over PCIe (CrashCat queue pointers).
    // On a drain cycle that found nothing (the common case while spinning for an
    // RPC response) only run it on every 16th cycle; any cycle that handled an
    // event, saw the expected response or failed still runs it every time.
    //
    if ((nvStatus != NV_WARN_NOTHING_TO_DO) || (nEventsHandled != 0) ||
        ((++emptyDrainCount & 0xF) == 0))
    {
        // If GSP-RM has died, the GPU will need to be reset
        if (!kgspHealthCheck_HAL(pGpu, pKernelGsp))
            return NV_ERR_RESET_REQUIRED;
    }
"""),
])
