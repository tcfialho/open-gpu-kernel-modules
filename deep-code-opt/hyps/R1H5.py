from _lib import patch
patch("src/nvidia/src/kernel/gpu/gsp/kernel_gsp.c", [
("    NvU32      gpuMaskUnused;\n\n#if defined(GSPRM_HWASAN_ENABLE)",
 "    NvU32      gpuMaskUnused;\n    NvU32      emptyPollCount = 0;\n\n#if defined(GSPRM_HWASAN_ENABLE)"),
("        {\n            osSpinLoop();\n        }\n    }\n\n    pRpc->timeoutCount = 0;",
 "        {\n            // Long waits (slow GSP RPC): after 32 empty polls back off with extra PAUSEs between PCIe RX-head reads.\n            NvU32 spins = (emptyPollCount++ >= 32) ? 4 : 1;\n            while (spins--)\n                osSpinLoop();\n        }\n    }\n\n    pRpc->timeoutCount = 0;"),
])
