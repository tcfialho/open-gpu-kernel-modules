from _lib import patch
patch("src/nvidia/src/kernel/gpu/gsp/kernel_gsp.c", [
("    NvU32      gpuMaskUnused;\n\n#if defined(GSPRM_HWASAN_ENABLE)",
 "    NvU32      gpuMaskUnused;\n    NvU32      sanityPollCount = 0;\n\n#if defined(GSPRM_HWASAN_ENABLE)"),
("        rpcStatus = _kgspRpcSanityCheck(pGpu, pKernelGsp, pRpc);\n        if (rpcStatus != NV_OK)\n        {",
 "        // GPU-state sanity checks are only needed periodically while spinning for a response\n        rpcStatus = ((sanityPollCount++ & 0x7) == 0) ? _kgspRpcSanityCheck(pGpu, pKernelGsp, pRpc) : NV_OK;\n        if (rpcStatus != NV_OK)\n        {"),
])
