from _lib import patch
patch("src/nvidia/src/kernel/gpu/intr/arch/turing/intr_tu102.c", [
("static NV_STATUS\n_intrGetLeafStatus_TU102\n", "static NV_STATUS __attribute__((unused))\n_intrGetLeafStatus_TU102\n"),
("    NV_ASSERT_OK_OR_RETURN(_intrGetLeafStatus_TU102(pGpu,\n                                                    pIntr,\n                                                    bUseCachedRegVal,\n                                                    cachedStaticRegVal,\n                                                    intrLeafValues,\n                                                    pThreadState));\n",
 "    // Leaf registers are read lazily below, only for leaves that actually hold a stall vector of a table engine\n    NvU32 leafReadMask = 0;\n    NvBool bEvenLeavesOnly = pIntr->getProperty(pIntr, PDB_PROP_INTR_READ_ONLY_EVEN_NUMBERED_INTR_LEAF_REGS);\n    if (bUseCachedRegVal)\n    {\n        intrLeafValues[4] = cachedStaticRegVal;\n        leafReadMask |= NVBIT(4);\n    }\n"),
("        leaf = intrLeafValues[leafIndex] & NVBIT(leafBit);\n\n        if (leaf == 0)",
 "        if (!(leafReadMask & NVBIT(leafIndex)))\n        {\n            leafReadMask |= NVBIT(leafIndex);\n            if (!(bEvenLeavesOnly && (leafIndex & 1)))\n                intrLeafValues[leafIndex] = intrReadRegLeaf_HAL(pGpu, pIntr, leafIndex, pThreadState);\n        }\n\n        leaf = intrLeafValues[leafIndex] & NVBIT(leafBit);\n\n        if (leaf == 0)"),
])
