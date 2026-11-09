from _lib import patch
patch("src/nvidia/arch/nvalloc/unix/src/unix_intr.c", [
("""                NvBool bNonStallTopPending = NV_FALSE;
                if (IS_GSP_CLIENT(pGpu) && !IS_VIRTUAL(pGpu) && !IS_GPU_GC6_STATE_ENTERED(pGpu))
                {
                    // GSP client: one INTR_TOP read decides whether any non-stall subtree is pending; the
                    // service pass below re-reads LEAF/EN registers itself, so the pre-read of every leaf is redundant.
                    NvU64 nsMask = intrGetIntrTopNonStallMask_HAL(pGpu, pIntr);
                    NvU32 topVal = intrReadRegTop_HAL(pGpu, pIntr, 0, &threadState);
                    NvU32 si;
                    bitVectorClrAll(&intr1Pending);
                    FOR_EACH_INDEX_IN_MASK(64, si, nsMask)
                    {
                        if (topVal & (NV_VIRTUAL_FUNCTION_PRIV_CPU_INTR_TOP_SUBTREE_INTR_PENDING << NV_CTRL_INTR_SUBTREE_TO_TOP_BIT(si)))
                            bNonStallTopPending = NV_TRUE;
                    }
                    FOR_EACH_INDEX_IN_MASK_END;
                }
                else
                {
                    intrGetPendingNonStall_HAL(pGpu, pIntr, &intr1Pending, &threadState);
                }
                intrCheckFecsEventbufferPending(pGpu, pIntr, &intr1Pending, &bCtxswLog);
                if (bNonStallTopPending || !bitVectorTestAllCleared(&intr1Pending))
                {
                    intrServiceNonStall_HAL(pGpu, pIntr, &intr1Pending, &threadState);
                    *serviced = NV_TRUE;
                }
""",
"""                if (IS_GSP_CLIENT(pGpu) && !IS_VIRTUAL(pGpu) && !IS_GPU_GC6_STATE_ENTERED(pGpu))
                {
                    // GSP client: the service pass reads INTR_TOP itself and returns an empty engine set when no
                    // non-stall subtree is pending, so no separate gate read is needed.
                    NvBool bFecsPending;
                    bitVectorClrAll(&intr1Pending);
                    intrCheckFecsEventbufferPending(pGpu, pIntr, &intr1Pending, &bCtxswLog);
                    bFecsPending = !bitVectorTestAllCleared(&intr1Pending);
                    intrServiceNonStall_HAL(pGpu, pIntr, &intr1Pending, &threadState);
                    if (bFecsPending || !bitVectorTestAllCleared(&intr1Pending))
                        *serviced = NV_TRUE;
                }
                else
                {
                    intrGetPendingNonStall_HAL(pGpu, pIntr, &intr1Pending, &threadState);
                    intrCheckFecsEventbufferPending(pGpu, pIntr, &intr1Pending, &bCtxswLog);
                    if (!bitVectorTestAllCleared(&intr1Pending))
                    {
                        intrServiceNonStall_HAL(pGpu, pIntr, &intr1Pending, &threadState);
                        *serviced = NV_TRUE;
                    }
                }
"""),
])
