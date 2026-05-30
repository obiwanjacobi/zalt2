; lib_mem.asm - memory manipulation routines

public mem_clear, mem_fill
; Clears memory to zeros.
; HL = start address
; BC = length in bytes
; Destroys: HL, DE, BC, A
mem_clear:
    xor a
    ; VVV fall-through to mem_fill

; Fills memory with a specific value.
; HL = start address
; BC = length in bytes
; A = value to fill
; Destroys: HL, DE, BC
mem_fill:
    ld d, h
    ld e, l
    inc de      ; de points to next byte
    ld (hl), a  ; fill first byte
    ldir        ; HL=Source, DE=Destination, BC=Count
    ret
