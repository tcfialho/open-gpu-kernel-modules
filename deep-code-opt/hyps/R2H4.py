from _lib import patch
patch("src/nvidia/src/kernel/gpu/gsp/kernel_gsp.c", [
("        if (nvStatus == NV_OK)\n            nEventsHandled++;\n        kgspDumpGspLogs(pKernelGsp, NV_FALSE);\n    }\n",
 "        if (nvStatus == NV_OK)\n            nEventsHandled++;\n    }\n    // one log dump per drain call instead of one per event\n    kgspDumpGspLogs(pKernelGsp, NV_FALSE);\n"),
])
