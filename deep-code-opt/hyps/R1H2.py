from _lib import patch
patch("src/nvidia/src/kernel/gpu/gsp/kernel_gsp.c", [
("    NvU32      gpuMaskUnused;\n\n#if defined(GSPRM_HWASAN_ENABLE)",
 "    NvU32      gpuMaskUnused;\n    NvU32      vblankPollCount = 0;\n\n#if defined(GSPRM_HWASAN_ENABLE)"),
("            kdispApplyAggressiveVblankHandlingWar(pGpu, pKernelDisplay);\n        }\n\n        {\n            osSpinLoop();",
 "            // Each check is an MMIO read over PCIe: look at every 8th poll iteration (~ well under one scanline).\n            if ((vblankPollCount++ & 0x7) == 0)\n                kdispApplyAggressiveVblankHandlingWar(pGpu, pKernelDisplay);\n        }\n\n        {\n            osSpinLoop();"),
])
