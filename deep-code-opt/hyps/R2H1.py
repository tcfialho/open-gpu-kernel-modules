from _lib import patch
patch("src/nvidia/src/kernel/gpu/intr/arch/turing/intr_nonstall_tu102.c", [
("    NvU32       i, pending;\n    NvU32       intr, intrVector;\n\n    bitVectorClrAll(pEngines);\n\n    if (!API_GPU_ATTACHED_SANITY_CHECK(pGpu))",
 "    NvU32       i, pending;\n    NvU32       intr, intrVector;\n    NvU32       topIdxCached = 0xFFFFFFFF;\n    NvU32       topPendingCached = 0;\n\n    bitVectorClrAll(pEngines);\n\n    if (!API_GPU_ATTACHED_SANITY_CHECK(pGpu))"),
("        // TODO Bug 3823562: optimize this and don't read on every loop\n        pending = intrReadRegTop_HAL(pGpu, pIntr, j, pThreadState);\n",
 "        // Bug 3823562: one MMIO read per distinct INTR_TOP index per pass (was: one per subtree)\n        if (j != topIdxCached)\n        {\n            topPendingCached = intrReadRegTop_HAL(pGpu, pIntr, j, pThreadState);\n            topIdxCached = j;\n        }\n        pending = topPendingCached;\n"),
])
