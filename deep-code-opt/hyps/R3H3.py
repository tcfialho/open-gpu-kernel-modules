from _lib import patch
patch("kernel-open/nvidia-uvm/uvm_gpu_semaphore.c", [
("    return uvm_gpu_tracking_semaphore_update_completed_value(tracking_sem) >= value;\n}",
 "    // No progress since the last update (payload == low 32 bits of completed_value): the locked update would just\n    // return the old, smaller value, so skip taking the lock/mutex on every poll iteration.\n    if (!gpu_semaphore_is_secure(&tracking_sem->semaphore) &&\n        (NvU32)completed == uvm_gpu_semaphore_get_payload(&tracking_sem->semaphore))\n        return false;\n\n    return uvm_gpu_tracking_semaphore_update_completed_value(tracking_sem) >= value;\n}"),
])
