; test_lib_ring_buffer8.asm - unit tests for the 8-bit ring buffer

#include "unit_tests.inc"

extern lib_ring_buffer8_construct, lib_ring_buffer8_canpush, lib_ring_buffer8_canpop
extern lib_ring_buffer8_push, lib_ring_buffer8_pop

ring_buffer8_construct: defs 7, 0xFF
ring_buffer8_canpush:   defb 0, 0, 3
ring_buffer8_canpop:    defb 0, 0, 3
ring_buffer8_push:      defb 0, 0, 3, 0
ring_buffer8_pop:       defb 1, 0, 3, 0x5A

UT_ring_buffer8_construct:
    ld hl, ring_buffer8_construct
    ld c, 7
    call lib_ring_buffer8_construct
    ld a, (ring_buffer8_construct+2)
    nop ; ASSERTION A == 3
    TC_END

UT_ring_buffer8_canpush:
    ld hl, ring_buffer8_canpush
    call lib_ring_buffer8_canpush
    jr nz, ring_buffer8_canpush_available
    ld a, 1
    jr ring_buffer8_canpush_check
ring_buffer8_canpush_available:
    xor a
ring_buffer8_canpush_check:
    nop ; ASSERTION A == 0
    TC_END

UT_ring_buffer8_canpop:
    ld hl, ring_buffer8_canpop
    call lib_ring_buffer8_canpop
    jr z, ring_buffer8_canpop_empty
    xor a
    jr ring_buffer8_canpop_check
ring_buffer8_canpop_empty:
    ld a, 1
ring_buffer8_canpop_check:
    nop ; ASSERTION A == 1
    TC_END

UT_ring_buffer8_push:
    ld hl, ring_buffer8_push
    ld a, 0xA5
    call lib_ring_buffer8_push
    ld a, (ring_buffer8_push+3)
    nop ; ASSERTION A == 0xA5
    ld a, (ring_buffer8_push)
    nop ; ASSERTION A == 1
    TC_END

UT_ring_buffer8_pop:
    ld hl, ring_buffer8_pop
    call lib_ring_buffer8_pop
    nop ; ASSERTION A == 0x5A
    ld a, (ring_buffer8_pop+1)
    nop ; ASSERTION A == 1
    TC_END
