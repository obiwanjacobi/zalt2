; test_lib_ring_buffer.asm - unit tests for the generic ring buffer

#include "unit_tests.inc"

extern lib_ring_buffer_construct, lib_ring_buffer_canpush, lib_ring_buffer_canpull
extern lib_ring_buffer_push, lib_ring_buffer_pop

ring_buffer_construct: defs 10, 0xFF
ring_buffer_canpush:   defb 0, 0, 0, 0, 4, 0
ring_buffer_canpull:   defb 0, 0, 0, 0, 4, 0
ring_buffer_push:      defb 0, 0, 0, 0, 4, 0, 0
ring_buffer_pop:       defb 1, 0, 0, 0, 4, 0, 0x5A

UT_ring_buffer_construct:
    ld hl, ring_buffer_construct
    ld bc, 10
    call lib_ring_buffer_construct
    ld a, (ring_buffer_construct+4)
    nop ; ASSERTION A == 4
    ld a, (ring_buffer_construct+5)
    nop ; ASSERTION A == 0
    TC_END

UT_ring_buffer_canpush:
    ld hl, ring_buffer_canpush
    call lib_ring_buffer_canpush
    jr nz, ring_buffer_canpush_available
    ld a, 1
    jr ring_buffer_canpush_check
ring_buffer_canpush_available:
    xor a
ring_buffer_canpush_check:
    nop ; ASSERTION A == 0
    TC_END

UT_ring_buffer_canpull:
    ld hl, ring_buffer_canpull
    call lib_ring_buffer_canpull
    jr z, ring_buffer_canpull_empty
    xor a
    jr ring_buffer_canpull_check
ring_buffer_canpull_empty:
    ld a, 1
ring_buffer_canpull_check:
    nop ; ASSERTION A == 1
    TC_END

UT_ring_buffer_push:
    ld hl, ring_buffer_push
    ld a, 0xA5
    call lib_ring_buffer_push
    ld a, (ring_buffer_push+6)
    nop ; ASSERTION A == 0xA5
    ld a, (ring_buffer_push)
    nop ; ASSERTION A == 1
    TC_END

UT_ring_buffer_pop:
    ld hl, ring_buffer_pop
    call lib_ring_buffer_pop
    nop ; ASSERTION A == 0x5A
    ld a, (ring_buffer_pop+2)
    nop ; ASSERTION A == 1
    TC_END
