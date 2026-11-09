from _lib import patch
patch("src/nvidia/src/kernel/gpu/gpu.c", [
("    if (sz == 0)\n        status = kceGetFaultMethodBufferSize(pGpu, &sz);\n\n    if (status == NV_OK)\n        *size = sz;",
 "    if (sz == 0)\n    {\n        status = kceGetFaultMethodBufferSize(pGpu, &sz);\n        // Constant per GPU: cache it (the field was read but never written, so every channel group paid a GSP RPC)\n        if (status == NV_OK)\n            pGpu->ceFaultMethodBufferSize = sz;\n    }\n\n    if (status == NV_OK)\n        *size = sz;"),
])
