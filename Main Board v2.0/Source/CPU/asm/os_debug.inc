; os_debug.inc  - OS debug utilities
; #include this file in the .asm where you need to reference these definitions.

extern mem_fill

; Fills memory with 0xFF in a DEBUG build - otherwise does nothing.
; HL = start address
; BC = length in bytes
; Destroys: F
#ifdef DEBUG
    #define mem_clear_dbg   \
        push hl             \ \
        push de             \ \
        push bc             \ \
        push af             \ \
        ld a, 0xFF          \ \
        call mem_fill       \ \
        pop af              \ \
        pop de              \ \
        pop bc              \ \
        pop hl
#else
    #define mem_clear_dbg
#endif
