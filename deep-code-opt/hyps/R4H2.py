from _lib import patch
patch("kernel-open/common/inc/nv-linux.h", [
("    return completion_done(&nvlfp->open_complete);\n",
 "    // completion_done() takes the completion's irqsave lock on every poll(); a plain acquire load of 'done' is enough\n    // to learn that open finished (complete_all() makes it non-zero and it never goes back).\n    return smp_load_acquire(&nvlfp->open_complete.done) != 0;\n"),
])
