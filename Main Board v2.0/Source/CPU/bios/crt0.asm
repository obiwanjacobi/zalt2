; crt0.asm — Z80 page 0 layout: RST vectors, IM2 vector table, NMI handler,
;             and system startup.
;
; This file must be linked first and placed at $0000 by the linker.
;
; Memory map (I register = $00, even IM2 vectors only):
;   $0000–$003F  RST $00–$38: 8 × (JP handler + NOP + 4 free bytes)
;   $0040–$004D  IM2 vectors: SYSINT 1–7  (vector bytes $40–$4C)
;   $004E–$005D  IM2 vectors: BIRQ0–7    (vector bytes $4E–$5C)
;   $005E–$0065  (free)
;   $0066–$0069  NMI: JP handler + NOP

SECTION code_crt_init

; RST dispatch targets (defined in dispatch.asm)
EXTERN rst_00, rst_08, rst_10, rst_18
EXTERN rst_20, rst_28, rst_30, rst_38

; IM2 interrupt service routines (SYSINT sourced by MCU, BIRQ by expansion bus)
EXTERN isr_sysint_1, isr_sysint_2, isr_sysint_3, isr_sysint_4
EXTERN isr_sysint_5, isr_sysint_6, isr_sysint_7
EXTERN isr_birq_0, isr_birq_1, isr_birq_2, isr_birq_3
EXTERN isr_birq_4, isr_birq_5, isr_birq_6, isr_birq_7

; =============================================================================
; RST vectors [$0000–$003F]
; Each slot: JP target (3 bytes) + NOP (1 byte) + 4 unused bytes = 8 bytes.
; The 4 unused bytes fall in the IM2 table but are never assigned a vector.
; =============================================================================

PUBLIC rst_00
rst_00:                     ; $0000 — also Z80 reset entry
    di
    jp   rst_00

    DEFW isr_null_handler   ; $04
    DEFW isr_null_handler   ; $06

PUBLIC rst_08
rst_08:                     ; $0008
    nop
    jp   rst_08

    DEFW isr_null_handler   ; $0C
    DEFW isr_null_handler   ; $0E

PUBLIC rst_10
rst_10:                     ; $0010
    nop
    jp   rst_10

    DEFW isr_null_handler   ; $14
    DEFW isr_null_handler   ; $16

PUBLIC rst_18
rst_18:                     ; $0018
    nop
    jp   rst_18

    DEFW isr_null_handler   ; $1C
    DEFW isr_null_handler   ; $1E

PUBLIC rst_20
rst_20:                     ; $0020
    nop
    jp   rst_20

    DEFW isr_null_handler   ; $24
    DEFW isr_null_handler   ; $26

PUBLIC rst_28
rst_28:                     ; $0028
    nop
    jp   rst_28

    DEFW isr_null_handler   ; $2C
    DEFW isr_null_handler   ; $2E

PUBLIC rst_30
rst_30:                     ; $0030
    nop
    jp   rst_30

    DEFW isr_null_handler   ; $34
    DEFW isr_null_handler   ; $36

PUBLIC rst_38
rst_38:                     ; $0038
    nop
    jp   rst_38

    DEFW isr_null_handler   ; $3C
    DEFW isr_null_handler   ; $3E

; =============================================================================
; IM2 vector table [$0040–$005D]
; I = $00; CPLD drives vector byte = $40 + irq_index * 2.
; =============================================================================

PUBLIC im2_vectors
im2_vectors:                ; $0040
    DEFW isr_sysint_1      ; $40  SYSINT level 1 (highest priority)
    DEFW isr_sysint_2      ; $42  SYSINT level 2
    DEFW isr_sysint_3      ; $44  SYSINT level 3
    DEFW isr_sysint_4      ; $46  SYSINT level 4
    DEFW isr_sysint_5      ; $48  SYSINT level 5
    DEFW isr_sysint_6      ; $4A  SYSINT level 6
    DEFW isr_sysint_7      ; $4C  SYSINT level 7
    DEFW isr_birq_0        ; $4E  BIRQ0 (highest expansion IRQ)
    DEFW isr_birq_1        ; $50  BIRQ1
    DEFW isr_birq_2        ; $52  BIRQ2
    DEFW isr_birq_3        ; $54  BIRQ3
    DEFW isr_birq_4        ; $56  BIRQ4
    DEFW isr_birq_5        ; $58  BIRQ5
    DEFW isr_birq_6        ; $5A  BIRQ6
    DEFW isr_birq_7        ; $5C  BIRQ7 (lowest expansion IRQ)
    
    DEFW isr_null_handler   ; $5E
    DEFW isr_null_handler   ; $60
    DEFW isr_null_handler   ; $62
    DEFW isr_null_handler   ; $64

; =============================================================================
; NMI handler [$0066] — memory protection fault (see mmu.asm)
; =============================================================================

nmi_handler:                ; $0066
    ; todo
    retn

; =============================================================================
; Null ISR — default handler for unassigned IM2 vector slots
; =============================================================================

PUBLIC isr_null_handler
isr_null_handler:
    ; todo: trap
    reti

; $C300: for the interrupt vectors that land on NOP (00) + JP (C3)
defs 0xC300 - ASMPC ; will error when we overwrite this marker
DEFW isr_null_handler

; $C3F3: for the interrupt vectors that land on DI (F3) + JP (C3)
defs 0xC3F3 - ASMPC ; will error when we overwrite this marker
DEFW isr_null_handler   ; vector $00
