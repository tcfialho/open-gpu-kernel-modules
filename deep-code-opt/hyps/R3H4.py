from _lib import patch
patch("kernel-open/nvidia/nv.c", [
("    if ((file->f_flags & O_NONBLOCK) == 0)\n        poll_wait(file, &nvlfp->waitqueue, wait);\n\n    NV_SPIN_LOCK_IRQSAVE(&nvlfp->fp_lock, eflags);\n",
 "    if ((file->f_flags & O_NONBLOCK) == 0)\n        poll_wait(file, &nvlfp->waitqueue, wait);\n\n    // Nothing pending: skip the irqsave lock round trip (a later event wakes the waitqueue registered above)\n    if ((READ_ONCE(nvlfp->event_data_head) == NULL) && !READ_ONCE(nvlfp->dataless_event_pending))\n        return 0;\n\n    NV_SPIN_LOCK_IRQSAVE(&nvlfp->fp_lock, eflags);\n"),
])
