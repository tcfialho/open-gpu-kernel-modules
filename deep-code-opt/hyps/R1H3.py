from _lib import patch
patch("src/nvidia/src/kernel/gpu/gsp/kernel_gsp.c", [
("    NvU32      gpuMaskUnused;\n\n#if defined(GSPRM_HWASAN_ENABLE)",
 "    NvU32      gpuMaskUnused;\n    NvU32      timeoutPollCount = 0;\n\n#if defined(GSPRM_HWASAN_ENABLE)"),
("        timeoutStatus = gpuCheckTimeout(pGpu, &timeout);\n\n        rpcStatus = _kgspRpcDrainEvents(",
 "        // gpuCheckTimeout() reads the clock (ktime_get_raw_ts64) every call; the timeout is in the 100s of ms, so sample every 8th iteration.\n        if ((timeoutPollCount++ & 0x7) == 0)\n            timeoutStatus = gpuCheckTimeout(pGpu, &timeout);\n\n        rpcStatus = _kgspRpcDrainEvents("),
])
