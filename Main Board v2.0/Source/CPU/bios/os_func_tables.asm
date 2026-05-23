section code_crt_init

public os_func_table, fs_func_table, video_func_table
public audio_func_table, reserved_func_table, debug_func_table

os_func_table:
    ;dw os_func_alloc
    ;dw os_func_free
    ;dw os_func_mmu_map

fs_func_table:

video_func_table:

audio_func_table:

reserved_func_table:

debug_func_table:

; filler for unassigned function-ids
no_op:
    ret
