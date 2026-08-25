#include "os_defs.inc"
#include "os_debug.inc"

extern mem_clear

public lib_ring_buffer16_construct
public lib_ring_buffer16_canpush, lib_ring_buffer16_canpop
public lib_ring_buffer16_push, lib_ring_buffer16_pop

; Ring buffer 16-bit layout at HL:
;   +0..+1: head (u16 index)
;   +2..+3: tail (u16 index)
;   +4..+5: mask (u16, capacity-1; capacity must be power-of-2)
;   +6..  : data bytes
;
; Size rules:
;   - This implementation uses one-slot-open full detection.
;   - Usable payload bytes = data_capacity - 1.
;   - data_capacity must be a power of 2 and intended for values > 256.
;   - total reserved bytes passed to construct = data_capacity + 6.

; Initializes the ring buffer at the given address.
; HL = address of ring buffer struct
; BC = total reserved bytes for this object: header=6 + data=2^n
; Destroys: HL, DE, BC, A
lib_ring_buffer16_construct:
	mem_clear_dbg

	; head = 0, tail = 0
	xor a
	ld (hl), a
	inc hl
	ld (hl), a
	inc hl
	ld (hl), a
	inc hl
	ld (hl), a
	inc hl

	; mask = (total_size - 6) - 1 = total_size - 7
	ld a, c
	sub 7
	ld c, a
	ld a, b
	sbc a, 0
	ld b, a
	ld (hl), c
	inc hl
	ld (hl), b
	ret

; Indicates whether the ring buffer has room to push.
; HL = address of ring buffer struct
; Returns: Z=0 if push is possible, Z=1 if full
; Destroys: BC, DE, HL, A
lib_ring_buffer16_canpush:
	push hl

	; DE = head
	ld e, (hl)
	inc hl
	ld d, (hl)
	inc hl

	; BC = tail
	ld c, (hl)
	inc hl
	ld b, (hl)
	inc hl

	; HL = mask
	ld a, (hl)
	inc hl
	ld h, (hl)
	ld l, a

	; next_head = (head + 1) & mask
	inc de
	ld a, e
	and l
	ld e, a
	ld a, d
	and h
	ld d, a

	; full when next_head == tail
	ld a, d
	cp b
	jr nz, lib_ring_buffer16_canpush_true
	ld a, e
	cp c
	pop hl
	ret

lib_ring_buffer16_canpush_true:
	; cp b already set Z=0
	pop hl
	ret

; Indicates whether the ring buffer has data to pop.
; HL = address of ring buffer struct
; Returns: Z=0 if pop is possible, Z=1 if empty
; Destroys: BC, DE, A
lib_ring_buffer16_canpop:
	push hl

	; DE = head
	ld e, (hl)
	inc hl
	ld d, (hl)
	inc hl

	; BC = tail
	ld c, (hl)
	inc hl
	ld b, (hl)

	ld a, d
	cp b
	jr nz, lib_ring_buffer16_canpop_true
	ld a, e
	cp c
	pop hl
	ret

lib_ring_buffer16_canpop_true:
	; cp b already set Z=0
	pop hl
	ret

; Pushes one byte into the ring buffer.
; HL = address of ring buffer struct
; A = byte to push
; Returns: none
; Destroys: BC, DE, HL, A
lib_ring_buffer16_push:
	push af                  ; payload
	push hl                  ; base pointer

	; DE = head
	ld e, (hl)
	inc hl
	ld d, (hl)
	inc hl

	; BC = tail
	ld c, (hl)
	inc hl
	ld b, (hl)
	inc hl

	; HL = mask
	ld a, (hl)
	inc hl
	ld h, (hl)
	ld l, a

	push de                  ; preserve old head

	; next_head = (head + 1) & mask
	inc de
	ld a, e
	and l
	ld e, a
	ld a, d
	and h
	ld d, a

	; full when next_head == tail
	ld a, d
	cp b
	jr nz, lib_ring_buffer16_push_can_write
	ld a, e
	cp c
	jr nz, lib_ring_buffer16_push_can_write
	rst $38
	defb PANIC_RING_BUFFER_PUSH_WHEN_FULL

lib_ring_buffer16_push_can_write:
	; BC = old head index
	pop bc

	; HL = base pointer
	pop hl
	pop af                   ; payload
	push hl                  ; keep base for head update
	push af                  ; keep payload for data write

	; HL = data_base + old_head
	ld a, 6
	add a, l
	ld l, a
	jr nc, lib_ring_buffer16_push_data_base_ok
	inc h
lib_ring_buffer16_push_data_base_ok:
	add hl, bc

	pop af                   ; payload
	ld (hl), a

	; store updated head (DE)
	pop hl
	ld (hl), e
	inc hl
	ld (hl), d
	ret

; Pops one byte from the ring buffer.
; HL = address of ring buffer struct
; Returns: A = byte popped
; Destroys: BC, DE, HL, A
lib_ring_buffer16_pop:
	push hl

	; DE = head
	ld e, (hl)
	inc hl
	ld d, (hl)
	inc hl

	; BC = tail
	ld c, (hl)
	inc hl
	ld b, (hl)
	inc hl

	; empty when head == tail
	ld a, d
	cp b
	jr nz, lib_ring_buffer16_pop_has_data
	ld a, e
	cp c
	jr nz, lib_ring_buffer16_pop_has_data
	rst $38
	defb PANIC_RING_BUFFER_POP_WHEN_EMPTY

lib_ring_buffer16_pop_has_data:
	; DE = mask, HL = data base
	ld e, (hl)
	inc hl
	ld d, (hl)
	inc hl

	; read byte at data_base + tail
	push bc
	add hl, bc
	ld a, (hl)
	pop bc
	push af

	; next_tail = (tail + 1) & mask
	inc bc
	ld a, c
	and e
	ld c, a
	ld a, b
	and d
	ld b, a

	; store updated tail (BC)
	pop af
	pop hl
	inc hl
	inc hl
	ld (hl), c
	inc hl
	ld (hl), b
	ret
