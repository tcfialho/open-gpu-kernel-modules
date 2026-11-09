from _lib import patch
patch("kernel-open/nvidia/nv.c", [
("    void *arg_copy = NULL;\n    size_t arg_size = 0;\n    int arg_cmd;\n",
 "    void *arg_copy = NULL;\n    size_t arg_size = 0;\n    int arg_cmd;\n    char arg_stack_buf[256] __aligned(16);\n"),
("    NV_KMALLOC(arg_copy, arg_size);\n    if (arg_copy == NULL)\n",
 "    // Most RM ioctl argument blocks are small: copy them through the stack instead of a kmalloc/kfree pair\n    if (arg_size <= sizeof(arg_stack_buf))\n        arg_copy = arg_stack_buf;\n    else\n        NV_KMALLOC(arg_copy, arg_size);\n    if (arg_copy == NULL)\n"),
("        NV_KFREE(arg_copy, arg_size);\n    }\n\n    return status;\n}",
 "        if (arg_copy != arg_stack_buf)\n            NV_KFREE(arg_copy, arg_size);\n    }\n\n    return status;\n}"),
])
