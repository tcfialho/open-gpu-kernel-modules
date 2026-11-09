from _lib import patch
patch("src/nvidia/src/kernel/gpu/intr/arch/turing/intr_nonstall_tu102.c", [
("            NvU32 intr = intrReadRegLeaf_HAL(pGpu, pIntr, j, pThreadState) &\n                         intrReadRegLeafEnSet_HAL(pGpu, pIntr, j, pThreadState);\n",
 "            // LEAF==0 makes the AND zero regardless of EN_SET: skip the second MMIO read\n            NvU32 intr = intrReadRegLeaf_HAL(pGpu, pIntr, j, pThreadState);\n            if (intr != 0)\n                intr &= intrReadRegLeafEnSet_HAL(pGpu, pIntr, j, pThreadState);\n"),
("            intr = intrReadRegLeaf_HAL(pGpu, pIntr, j, pThreadState) &\n                   intrReadRegLeafEnSet_HAL(pGpu, pIntr, j, pThreadState);\n",
 "            intr = intrReadRegLeaf_HAL(pGpu, pIntr, j, pThreadState);\n            if (intr != 0)\n                intr &= intrReadRegLeafEnSet_HAL(pGpu, pIntr, j, pThreadState);\n"),
])
