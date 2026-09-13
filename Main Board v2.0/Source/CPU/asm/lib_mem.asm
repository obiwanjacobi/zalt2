; lib_mem.asm - memory manipulation routines

public mem_clear, mem_fill
; Clears memory to zeros.
; HL = start address
; BC = length in bytes (>1)
; Destroys: HL, DE, BC, A
; Note: Use assignement (or "ld (hl), 0") for 1 byte.
mem_clear:
    xor a
    ; VVV fall-through to mem_fill

; Fills memory with a specific value.
; HL = start address
; BC = length in bytes (>1)
; A = value to fill
; Destroys: HL, DE, BC
; Note: Use assignement (or "ld (hl), a") for 1 byte.
mem_fill:
    ; TODO: add debug check on BC=1
    ld d, h
    ld e, l
    inc de      ; de points to next byte
    dec bc      ; BC counts remaining bytes
    ld (hl), a  ; fill first byte
    ldir        ; HL=Source, DE=Destination, BC=Count
    ret

; --------------------------------------------------------------------------
; Fixed-size clears for small structures.
;
; LDIR costs 21 T-states/byte, vs. 13 T-states/byte (7 for "ld (hl),a" + 6 for
; "inc hl") for a straight-line unrolled store. So a fixed-size routine is
; *always* faster per call than setting up BC and calling mem_clear, for any
; size - there is no size where calling mem_clear is cheaper in cycles:
;
;   size  mem_clearN (call+body)   mem_clear (ld bc,n + call + body)
;   1      10c  (n/a, see mem_clear1)     buggy, do not use (see note above)
;   2      51c                            84c
;   4      77c                            126c
;   8      129c                           210c
;
; The only real trade-off is code size (one routine per fixed size vs. the
; single generic mem_clear). A dedicated routine only pays off in code size
; once it is used from enough call sites (each call site costs 3 bytes for
; the CALL either way, so it's the shared body size vs. the per-call bc
; setup that decides it, roughly 3+ call sites for size 4, 6+ for size 8).
; For sizes not listed here, or ones used from only 1-2 places, prefer the
; generic mem_clear.
; --------------------------------------------------------------------------

public mem_clear2, mem_clear3, mem_clear4
public mem_fill2, mem_fill3, mem_fill4

; Clears 2 bytes. HL = address, ends pointing at the last byte cleared.
; Destroys: A, HL.
mem_clear2:
    xor a
; Fills 2 bytes. HL = address, ends pointing at the last byte cleared.
; Destroys: HL.
mem_fill2:
    ld (hl), a
    inc hl
    ld (hl), a
    ret

; Clears 3 bytes. HL = address, ends pointing at the last byte cleared.
; Destroys: A, HL.
mem_clear3:
    xor a
; Fills 3 bytes. HL = address, ends pointing at the last byte cleared.
; Destroys: HL.
mem_fill3:
    ld (hl), a
    inc hl
    ld (hl), a
    inc hl
    ld (hl), a
    ret

; Clears 4 bytes. HL = address, ends pointing at the last byte cleared.
; Destroys: A, HL.
mem_clear4:
    xor a
; Fills 4 bytes. HL = address, ends pointing at the last byte cleared.
; Destroys: HL.
mem_fill4:
    ld (hl), a
    inc hl
    ld (hl), a
    inc hl
    ld (hl), a
    inc hl
    ld (hl), a
    ret
