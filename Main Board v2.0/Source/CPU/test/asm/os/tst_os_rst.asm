#include "tst_func_tables.inc"
#include "unit_tests.inc"

extern os_rst_08
extern tst_func0_called
extern tst_func1_sp_ok
extern tst_func2_bc, tst_func2_de, tst_func2_hl, tst_func2_a
extern var_os_task_current, var_os_task_table

; Verify RST08 dispatches OS function 0 and restores current caller registers.
UT_os_rst08_dispatches_func0:
    ; clear dispatch flag
    xor a
    ld (tst_func0_called), a

    ; load known values into all tested registers
    ld bc, 0x1234
    ld de, 0x5678
    ld hl, 0x9abc
    ld ix, 0xdef0
    ld iy, 0x0fed
    ld a, 0x42

    ; call RST08 with inline function id (same stack convention as RST instruction)
    call os_rst_08
    defb OS_FUNC_BASIC_DISPATCH

    ; dispatcher must restore caller AF (A=0x42), not the function's xor a result
    nop ; ASSERTION A == 0x42

    ; confirm the function body executed
    ld a, (tst_func0_called)
    nop ; ASSERTION A == 1

    ; confirm each caller register is preserved
    ld a, h
    nop ; ASSERTION A == 0x9a
    ld a, l
    nop ; ASSERTION A == 0xbc

    ld a, b
    nop ; ASSERTION A == 0x12
    ld a, c
    nop ; ASSERTION A == 0x34

    ld a, d
    nop ; ASSERTION A == 0x56
    ld a, e
    nop ; ASSERTION A == 0x78

    push ix
    pop hl
    ld a, h
    nop ; ASSERTION A == 0xde
    ld a, l
    nop ; ASSERTION A == 0xf0

    push iy
    pop hl
    ld a, h
    nop ; ASSERTION A == 0x0f
    ld a, l
    nop ; ASSERTION A == 0xed

    TC_END

tst_sp_before: defw 0
; Verify RST08 switches SP to the OS stack before dispatching the function.
UT_os_rst08_sp_switch:
    xor a
    ld (tst_func1_sp_ok), a
    ld hl, var_os_task_current
    ld (hl), 1
    ld hl, var_os_task_table+2
    ld (hl), 0x00
    inc hl
    ld (hl), 0xC0

    ; capture SP; must be unchanged after reti
    ld hl, 0
    add hl, sp
    ld (tst_sp_before), hl

    call os_rst_08
    defb OS_FUNC_SP_CHECK

    ld a, (tst_func1_sp_ok)
    nop ; ASSERTION A == 1

    ; SP must equal the pre-call value (dispatcher restores caller stack)
    ld hl, 0
    add hl, sp
    ex de, hl
    ld hl, (tst_sp_before)
    or a
    sbc hl, de
    ld a, h
    nop ; ASSERTION A == 0
    ld a, l
    nop ; ASSERTION A == 0

    TC_END

; Verify BC, DE, HL passed by the caller reach the dispatched function body.
UT_os_rst08_params_reach_func:
    ld hl, 0
    ld (tst_func2_bc), hl
    ld (tst_func2_de), hl
    ld (tst_func2_hl), hl
    xor a
    ld (tst_func2_a), a

    ld bc, 0x1122
    ld de, 0x3344
    ld hl, 0x5566
    ld a, 0x77

    call os_rst_08
    defb OS_FUNC_PARAMS

    ld hl, (tst_func2_bc)
    ld a, h
    nop ; ASSERTION A == 0x11
    ld a, l
    nop ; ASSERTION A == 0x22

    ld hl, (tst_func2_de)
    ld a, h
    nop ; ASSERTION A == 0x33
    ld a, l
    nop ; ASSERTION A == 0x44

    ld hl, (tst_func2_hl)
    ld a, h
    nop ; ASSERTION A == 0x55
    ld a, l
    nop ; ASSERTION A == 0x66

    ld a, (tst_func2_a)
    nop ; ASSERTION A == 0x77

    TC_END
