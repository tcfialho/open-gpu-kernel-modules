from _lib import patch
patch("kernel-open/nvidia-uvm/uvm_common.h", [
("    NvU64 start_time_ns;\n    NvU64 print_time_ns;\n} uvm_spin_loop_t;",
 "    NvU64 start_time_ns;\n    NvU64 print_time_ns;\n    NvU32 iter;\n} uvm_spin_loop_t;"),
("    spin->start_time_ns = curr;\n    spin->print_time_ns = curr;\n}",
 "    spin->start_time_ns = curr;\n    spin->print_time_ns = curr;\n    spin->iter = 0;\n}"),
])
patch("kernel-open/nvidia-uvm/uvm_common.c", [
("NV_STATUS uvm_spin_loop(uvm_spin_loop_t *spin)\n{\n    NvU64 curr = NV_GETTIME();\n",
 "NV_STATUS uvm_spin_loop(uvm_spin_loop_t *spin)\n{\n    NvU64 curr;\n\n    // The clock read (ktime_get_raw_ts64) dominates a spin iteration; the schedule/print thresholds are ms..s, so sample every 16th call.\n    if ((spin->iter++ & 0xF) != 0) {\n        cpu_relax();\n        return NV_OK;\n    }\n\n    curr = NV_GETTIME();\n"),
])
