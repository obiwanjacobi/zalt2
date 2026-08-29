section code_crt_init

public os_func_table, fs_func_table, video_func_table
public audio_func_table, reserved_func_table, debug_func_table

os_func_table:
    defw no_op
    ;defw os_func_alloc
    ;defw os_func_free
    ;defw os_func_mmu_map

fs_func_table:
    defw no_op

video_func_table:
    defw no_op

audio_func_table:
    defw no_op

reserved_func_table:
    defw no_op

debug_func_table:
    defw no_op

; filler for unassigned function-ids
no_op:
    ret
