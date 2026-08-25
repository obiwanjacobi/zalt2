#include "os_defs.inc"
#include "os_debug.inc"

public lib_ring_buffer_construct
public lib_ring_buffer_canpush, lib_ring_buffer_canpull
public lib_ring_buffer_push, lib_ring_buffer_pop

; Ring buffer layout at HL:
;   +0..+1: head (u16 index)
;   +2..+3: tail (u16 index)
;   +4..+5: capacity in bytes (u16)
;   +6..  : data bytes
;
; Initializes the ring buffer at the given address.
; HL = address of ring buffer struct
; BC = size of reserved memory pointed to by HL (number of bytes)
; Destroys: HL, BC, A
lib_ring_buffer_construct:
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

    ; capacity = total_size - 6
    ld a, c
    sub 6
    ld c, a
    ld a, b
    sbc a, 0
    ld b, a
    ld (hl), c
    inc hl
    ld (hl), b
    ret

; Indicates whether the ring buffer is full (cannot push).
; HL = address of ring buffer struct
; Returns: Z=0 if push is possible, Z=1 if full
; Destroys: BC, DE, A
lib_ring_buffer_canpush:
    push hl

    ; BC = head
    ld c, (hl)
    inc hl
    ld b, (hl)
    inc hl

    ; DE = tail
    ld e, (hl)
    inc hl
    ld d, (hl)
    inc hl

    ; HL = capacity
    ld a, (hl)
    inc hl
    ld h, (hl)
    ld l, a

    ; next_head = (head + 1) % capacity
    inc bc
    ld a, b
    cp h
    jr nz, lib_ring_buffer_canpush_cmp_tail
    ld a, c
    cp l
    jr nz, lib_ring_buffer_canpush_cmp_tail
    xor a
    ld b, a
    ld c, a

.lib_ring_buffer_canpush_cmp_tail
    ; full when next_head == tail
    ld a, b
    cp d
    jr nz, lib_ring_buffer_canpush_ret_true
    ld a, c
    cp e
.lib_ring_buffer_canpush_ret_true
    ; can-push path: Z is assigned from the last cp
    pop hl
    ret

; Indicates whether the ring buffer is empty (cannot pop).
; HL = address of ring buffer struct
; Returns: Z=0 if pull is possible, Z=1 if empty
; Destroys: BC, DE, A
lib_ring_buffer_canpull:
    push hl

    ; BC = head
    ld c, (hl)
    inc hl
    ld b, (hl)
    inc hl

    ; DE = tail
    ld e, (hl)
    inc hl
    ld d, (hl)

    ; can pull when head != tail
    ld a, b
    cp d
    jr nz, lib_ring_buffer_canpull_ret_true
    ld a, c
    cp e
.lib_ring_buffer_canpull_ret_true
    ; can-pull path: Z is assigned from the last cp
    pop hl
    ret

; Pushes a byte onto the ring buffer.
; HL = address of ring buffer struct
; A = byte to push
; Returns: none
; Destroys: BC, DE, HL, A
lib_ring_buffer_push:
    push af                  ; payload
    push hl                  ; base pointer

    ; BC = head
    ld c, (hl)
    inc hl
    ld b, (hl)
    inc hl

    ; DE = tail
    ld e, (hl)
    inc hl
    ld d, (hl)
    inc hl

    ; HL = capacity
    ld a, (hl)
    inc hl
    ld h, (hl)
    ld l, a

    push bc                  ; preserve old head

    ; next_head = (head + 1) % capacity
    inc bc
    ld a, b
    cp h
    jr nz, lib_ring_buffer_push_check_full
    ld a, c
    cp l
    jr nz, lib_ring_buffer_push_check_full
    xor a
    ld b, a
    ld c, a

.lib_ring_buffer_push_check_full
    ; full when next_head == tail
    ld a, b
    cp d
    jr nz, lib_ring_buffer_push_do_write
    ld a, c
    cp e
    jr nz, lib_ring_buffer_push_do_write

    rst $38
    defb PANIC_RING_BUFFER_PUSH_WHEN_FULL

.lib_ring_buffer_push_do_write
    ; DE = old head (index used for write address)
    pop de

    ; HL = base pointer
    pop hl
    pop af                   ; payload
    push hl                  ; keep base for head update
    push af                  ; keep payload for data write

    ; HL = data_base + old_head
    ld a, 6
    add a, l
    ld l, a
    jr nc, lib_ring_buffer_push_data_base_ok
    inc h
.lib_ring_buffer_push_data_base_ok
    add hl, de

    pop af                   ; payload
    ld (hl), a

    ; store updated head (BC)
    pop hl
    ld (hl), c
    inc hl
    ld (hl), b
    ret

; Pops a byte from the ring buffer.
; HL = address of ring buffer struct
; Returns: A = byte popped
; Destroys: BC, DE, HL, A
lib_ring_buffer_pop:
    push hl

    ; BC = head
    ld c, (hl)
    inc hl
    ld b, (hl)

    ; DE = tail
    inc hl
    ld e, (hl)
    inc hl
    ld d, (hl)

    ; empty when head == tail
    ld a, b
    cp d
    jr nz, lib_ring_buffer_pop_have_data
    ld a, c
    cp e
    jr nz, lib_ring_buffer_pop_have_data

    rst $38
    defb PANIC_RING_BUFFER_POP_WHEN_EMPTY

.lib_ring_buffer_pop_have_data
    ; BC = capacity, HL = data base
    inc hl
    ld c, (hl)
    inc hl
    ld b, (hl)
    inc hl

    ; read byte at data_base + tail
    push de
    add hl, de
    ld a, (hl)
    pop de
    push af

    ; next_tail = (tail + 1) % capacity
    inc de
    ld a, d
    cp b
    jr nz, lib_ring_buffer_pop_store_tail
    ld a, e
    cp c
    jr nz, lib_ring_buffer_pop_store_tail
    xor a
    ld d, a
    ld e, a

.lib_ring_buffer_pop_store_tail
    pop af
    pop hl
    inc hl
    inc hl
    ld (hl), e
    inc hl
    ld (hl), d

    ret
