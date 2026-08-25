; test_lib_ring_buffer16.asm - unit tests for the 16-bit ring buffer

#include "unit_tests.inc"

extern lib_ring_buffer16_construct, lib_ring_buffer16_canpush, lib_ring_buffer16_canpop
extern lib_ring_buffer16_push, lib_ring_buffer16_pop

ring_buffer16_construct: defs 262, 0xFF
ring_buffer16_canpush:   defb 0xFE, 0, 0, 0, 0xFF, 0
ring_buffer16_canpop:    defb 1, 0, 0, 0, 0xFF, 0
ring_buffer16_push:      defb 0xFF, 0, 0xFE, 0, 0xFF, 0
                         defs 0xFF, 0
                         defb 0x7F
ring_buffer16_pop:       defb 1, 0, 0, 0, 0xFF, 0, 0x5A

UT_ring_buffer16_construct:
    ld hl, ring_buffer16_construct
    ld bc, 262
    call lib_ring_buffer16_construct
    ld a, (ring_buffer16_construct+4)
    nop ; ASSERTION A == 0xFF
    ld a, (ring_buffer16_construct+5)
    nop ; ASSERTION A == 0
    TC_END

UT_ring_buffer16_canpush:
    ld hl, ring_buffer16_canpush
    call lib_ring_buffer16_canpush
    jr nz, ring_buffer16_canpush_available
    ld a, 1
    jr ring_buffer16_canpush_check
ring_buffer16_canpush_available:
    xor a
ring_buffer16_canpush_check:
    nop ; ASSERTION A == 0
    TC_END

UT_ring_buffer16_canpop:
    ld hl, ring_buffer16_canpop
    call lib_ring_buffer16_canpop
    jr nz, ring_buffer16_canpop_available
    ld a, 1
    jr ring_buffer16_canpop_check
ring_buffer16_canpop_available:
    xor a
ring_buffer16_canpop_check:
    nop ; ASSERTION A == 0
    TC_END

UT_ring_buffer16_push:
    ld hl, ring_buffer16_push
    ld a, 0x7F
    call lib_ring_buffer16_push
    ld a, (ring_buffer16_push)
    nop ; ASSERTION A == 0
    ld a, (ring_buffer16_push+1)
    nop ; ASSERTION A == 0
    ld a, (ring_buffer16_push+6+0xFF)
    nop ; ASSERTION A == 0x7F
    TC_END

UT_ring_buffer16_pop:
    ld hl, ring_buffer16_pop
    call lib_ring_buffer16_pop
    nop ; ASSERTION A == 0x5A
    ld a, (ring_buffer16_pop+2)
    nop ; ASSERTION A == 1
    ld a, (ring_buffer16_pop+3)
    nop ; ASSERTION A == 0
    TC_END
