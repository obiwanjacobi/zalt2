public os_func_table, fs_func_table, video_func_table
public audio_func_table, reserved_func_table, debug_func_table
public tst_func0_called, tst_func1_sp_ok
public tst_func2_bc, tst_func2_de, tst_func2_hl, tst_func2_a

tst_func0_called: defb 0
tst_func1_sp_ok:  defb 0
tst_func2_bc:     defw 0
tst_func2_de:     defw 0
tst_func2_hl:     defw 0
tst_func2_a:      defb 0

os_func_table:
    defw rst_test_func0
    defw rst_test_func1
    defw rst_test_func2

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

rst_test_func0:
    ld a, 1
    ld (tst_func0_called), a
    xor a
    ret

rst_test_func1:
    ; SP high byte == 0xBF: two dispatcher pushes below OS SP top (0xC000)
    ld hl, 0
    add hl, sp
    ld a, h
    cp 0xbf
    ld a, 1
    jr z, tst_func1_sp_end
    xor a
tst_func1_sp_end:
    ld (tst_func1_sp_ok), a
    ret

rst_test_func2:
    ld (tst_func2_a), a
    ld (tst_func2_hl), hl
    ld (tst_func2_bc), bc
    ld (tst_func2_de), de
    ret
