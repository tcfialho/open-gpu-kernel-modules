from _lib import patch
patch("src/nvidia/src/kernel/gpu/gsp/kernel_gsp.c", [
("    NvU32      gpuMaskUnused;\n\n#if defined(GSPRM_HWASAN_ENABLE)",
 "    NvU32      gpuMaskUnused;\n    NvU32      vblankPollCount = 0;\n    NvU32      timeoutPollCount = 0;\n    NvU32      emptyPollCount = 0;\n\n#if defined(GSPRM_HWASAN_ENABLE)"),
("            kdispApplyAggressiveVblankHandlingWar(pGpu, pKernelDisplay);\n        }\n\n        {\n            osSpinLoop();\n        }\n    }\n\n    pRpc->timeoutCount = 0;",
 "            if ((vblankPollCount++ & 0x7) == 0)\n                kdispApplyAggressiveVblankHandlingWar(pGpu, pKernelDisplay);\n        }\n\n        {\n            NvU32 spins = (emptyPollCount++ >= 32) ? 4 : 1;\n            while (spins--)\n                osSpinLoop();\n        }\n    }\n\n    pRpc->timeoutCount = 0;"),
("        timeoutStatus = gpuCheckTimeout(pGpu, &timeout);\n\n        rpcStatus = _kgspRpcDrainEvents(",
 "        if ((timeoutPollCount++ & 0x7) == 0)\n            timeoutStatus = gpuCheckTimeout(pGpu, &timeout);\n\n        rpcStatus = _kgspRpcDrainEvents("),
])
