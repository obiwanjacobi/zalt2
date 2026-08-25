; test_lib_mem.asm - unit tests for asm/lib_mem.asm

#include "unit_tests.inc"

extern mem_clear, mem_fill

guard_lo:   defb 0x5A
buffer:     defs 8, 0x11
guard_hi:   defb 0xA5

UT_mem_fill_writes_all_bytes:
    ld hl, buffer
    ld bc, 8
    ld a, 0x42
    call mem_fill

    ld a, (buffer)
    nop ; ASSERTION A == 0x42
    ld a, (buffer+7)
    nop ; ASSERTION A == 0x42
    TC_END

UT_mem_fill_keeps_guards:
    ld hl, guard_lo
    ld (hl), 0x5A
    ld hl, guard_hi
    ld (hl), 0xA5

    ld hl, buffer
    ld bc, 8
    ld a, 0xFF
    call mem_fill

    ld a, (guard_lo)
    nop ; ASSERTION A == 0x5A
    ld a, (guard_hi)
    nop ; ASSERTION A == 0xA5
    TC_END

UT_mem_clear_zeroes_all_bytes:
    ld hl, buffer
    ld bc, 8
    ld a, 0xFF
    call mem_fill

    ld hl, buffer
    ld bc, 8
    call mem_clear

    ld a, (buffer)
    nop ; ASSERTION A == 0
    ld a, (buffer+7)
    nop ; ASSERTION A == 0
    TC_END
