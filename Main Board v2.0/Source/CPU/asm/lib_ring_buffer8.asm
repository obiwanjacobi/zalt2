extern mem_clear

#include "os_defs.inc"
#include "os_debug.inc"

public lib_ring_buffer8_construct
public lib_ring_buffer8_canpush, lib_ring_buffer8_canpop
public lib_ring_buffer8_push, lib_ring_buffer8_pop

; Ring buffer 8-bit layout at HL:
;   +0: head (u8 index)
;   +1: tail (u8 index)
;   +2: mask (u8, capacity-1; capacity must be power-of-2)
;   +3..: data bytes
;
; Size rules:
;   - This implementation uses one-slot-open full detection.
;   - Usable payload bytes = data_capacity - 1.
;   - data_capacity must be a power of 2 (1, 2, 4, 8, 16, 32, 64, 128).
;   - total reserved bytes passed to construct = data_capacity + 3.

; Initializes the ring buffer at the given address.
; HL = address of ring buffer struct
; C = total reserved bytes for this object: header=3 + data=^2
; Destroys: HL, A
lib_ring_buffer8_construct:
	mem_clear_dbg

	xor a
	ld (hl), a              ; head = 0
	inc hl
	ld (hl), a              ; tail = 0
	inc hl

	; mask = (total_size - 3) - 1 = total_size - 4
	ld a, c
	sub 4
	ld (hl), a
	ret

; Indicates whether the ring buffer has room to push.
; HL = address of ring buffer struct
; Returns: Z=0 if push is possible, Z=1 if full
; Destroys: HL, BC, E, A
lib_ring_buffer8_canpush:
	ld b, (hl)              ; head
	inc hl
	ld c, (hl)              ; tail
	inc hl
	ld e, (hl)              ; mask

	ld a, b
	inc a
	and e                   ; next_head = (head + 1) & mask
	cp c
	; cp c sets Z directly for the return contract
	ret

; Indicates whether the ring buffer has data to pop.
; HL = address of ring buffer struct
; Returns: Z=0 if pop is possible, Z=1 if empty
; Destroys: HL, C, A
lib_ring_buffer8_canpop:
	ld a, (hl)              ; head
	inc hl
	ld c, (hl)              ; tail
	cp c                    ; Z set when empty
	ret

; Pushes one byte into the ring buffer.
; HL = address of ring buffer struct
; A = byte to push
; Returns: none
; Destroys: BC, DE, HL, A
lib_ring_buffer8_push:
	push af                 ; payload
	push hl                 ; base

	ld b, (hl)              ; head
	inc hl
	ld c, (hl)              ; tail
	inc hl
	ld e, (hl)              ; mask

	ld a, b
	inc a
	and e                   ; next_head
	cp c
	jr nz, lib_ring_buffer8_push_can_write
	rst $38
	defb PANIC_RING_BUFFER_PUSH_WHEN_FULL

lib_ring_buffer8_push_can_write:
	ld c, a                 ; preserve next_head

	; write byte at data[head]
	pop hl                  ; base
	push hl                 ; keep base for head update
	inc hl
	inc hl
	inc hl                  ; data base
	ld e, b                 ; old head index
	ld d, 0
	add hl, de

	pop af                  ; payload
	ld (hl), a

	; store updated head
	pop hl
	ld (hl), c
	ret

; Pops one byte from the ring buffer.
; HL = address of ring buffer struct
; Returns: A = byte popped
; Destroys: BC, DE, HL, A
lib_ring_buffer8_pop:
	push hl

	ld a, (hl)              ; head
	inc hl
	ld c, (hl)              ; tail
	cp c
	jr nz, lib_ring_buffer8_pop_has_data
	rst $38
	defb PANIC_RING_BUFFER_POP_WHEN_EMPTY

lib_ring_buffer8_pop_has_data:

	inc hl
	ld b, (hl)              ; mask

	; read byte at data[tail]
	pop hl                  ; base
	push hl                 ; keep base for tail update
	inc hl
	inc hl
	inc hl                  ; data base
	ld e, c
	ld d, 0
	add hl, de
	ld a, (hl)
	ex af, af'              ; preserve return byte while updating tail

	; tail = (tail + 1) & mask
	pop hl
	inc hl
	ld a, c
	inc a
	and b
	ld (hl), a

	ex af, af'
	ret
