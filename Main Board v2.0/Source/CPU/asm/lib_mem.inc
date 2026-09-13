; lib_mem.inc - compile-time dispatch to the fastest mem_clear/mem_fill for a fixed size.
; #include this file where you need MEM_CLEAR or MEM_FILL.
;
; Example (called from C via a thin asm wrapper, HL passed by __z88dk_fastcall):
;   /* C side */
;   extern void ClearMyStruct(MyStruct *s) __z88dk_fastcall;
;
;   ; asm side
;   #include "lib_mem.inc"
;   public _ClearMyStruct
;   _ClearMyStruct:
;       MEM_CLEAR MYSTRUCT_SIZE   ; HL already = s
;       ret

extern mem_clear, mem_clear2, mem_clear3, mem_clear4
extern mem_fill, mem_fill2, mem_fill3, mem_fill4

; Clears n bytes at HL, picking the fastest implementation for a compile-time
; constant n (e.g. a STRUCT_SIZE defc). Falls back to mem_clear for n > 4.
; HL = start address. Destroys: A, BC, DE, HL (worst case, see chosen routine).
MEM_CLEAR: MACRO n
    IF n = 1
        ld (hl), 0
    ELSE
        IF n = 2
            call mem_clear2
        ELSE
            IF n = 3
                call mem_clear3
            ELSE
                IF n = 4
                    call mem_clear4
                ELSE
                    ld bc, n
                    call mem_clear
                ENDIF
            ENDIF
        ENDIF
    ENDIF
ENDM

; Fills n bytes at HL with A, picking the fastest implementation for a
; compile-time constant n (e.g. a STRUCT_SIZE defc). Falls back to mem_fill
; for n > 4.
; HL = start address, A = fill value. Destroys: BC, DE, HL (worst case).
MEM_FILL: MACRO n
    IF n = 1
        ld (hl), a
    ELSE
        IF n = 2
            call mem_fill2
        ELSE
            IF n = 3
                call mem_fill3
            ELSE
                IF n = 4
                    call mem_fill4
                ELSE
                    ld bc, n
                    call mem_fill
                ENDIF
            ENDIF
        ENDIF
    ENDIF
ENDM
