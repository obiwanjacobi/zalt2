; os_page0.asm — Z80 page 0 layout: RST vectors, IM2 vector table, NMI handler,
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

section code_crt_init
org $0000

; RST dispatch targets (defined in os_rst.asm)
extern os_rst_00, os_rst_08, os_rst_10, os_rst_18
extern os_rst_20, os_rst_28, os_rst_30, os_rst_38

; IM2 interrupt service routines (SYSINT sourced by MCU, BIRQ by expansion bus)
extern isr_sysint_1, isr_sysint_2, isr_sysint_3, isr_sysint_4
extern isr_sysint_5, isr_sysint_6, isr_sysint_7
extern isr_birq_0, isr_birq_1, isr_birq_2, isr_birq_3
extern isr_birq_4, isr_birq_5, isr_birq_6, isr_birq_7

; =============================================================================
; RST vectors [$0000–$003F]
; Each slot: JP target (3 bytes) + NOP (1 byte) + 4 unused bytes = 8 bytes.
; The 4 unused bytes fall in the IM2 table but are never assigned a vector.
; =============================================================================

rst00:                     ; $0000 — also Z80 reset entry
    di
    jp   os_rst_00

    defw isr_null_handler   ; $04
    defw isr_null_handler   ; $06

rst08:                     ; $0008
    di
    jp   os_rst_08

    defw isr_null_handler   ; $0C
    defw isr_null_handler   ; $0E

rst10:                     ; $0010
    di
    jp   os_rst_10

    defw isr_null_handler   ; $14
    defw isr_null_handler   ; $16

rst18:                     ; $0018
    di
    jp   os_rst_18

    defw isr_null_handler   ; $1C
    defw isr_null_handler   ; $1E

rst20:                     ; $0020
    di
    jp   os_rst_20

    defw isr_null_handler   ; $24
    defw isr_null_handler   ; $26

rst28:                     ; $0028
    di
    jp   os_rst_28

    defw isr_null_handler   ; $2C
    defw isr_null_handler   ; $2E

rst30:                     ; $0030
    di
    jp   os_rst_30

    defw isr_null_handler   ; $34
    defw isr_null_handler   ; $36

rst38:                     ; $0038
    di
    jp   os_rst_38

    defw isr_null_handler   ; $3C
    defw isr_null_handler   ; $3E

; =============================================================================
; IM2 vector table [$0040–$005D]
; I = $00; CPLD drives vector byte = $40 + irq_index * 2.
; =============================================================================

    defw isr_sysint_1      ; $40  SYSINT level 1 (highest priority)
    defw isr_sysint_2      ; $42  SYSINT level 2
    defw isr_sysint_3      ; $44  SYSINT level 3
    defw isr_sysint_4      ; $46  SYSINT level 4
    defw isr_sysint_5      ; $48  SYSINT level 5
    defw isr_sysint_6      ; $4A  SYSINT level 6
    defw isr_sysint_7      ; $4C  SYSINT level 7

    defw isr_birq_0        ; $4E  BIRQ0 (highest expansion IRQ)
    defw isr_birq_1        ; $50  BIRQ1
    defw isr_birq_2        ; $52  BIRQ2
    defw isr_birq_3        ; $54  BIRQ3
    defw isr_birq_4        ; $56  BIRQ4
    defw isr_birq_5        ; $58  BIRQ5
    defw isr_birq_6        ; $5A  BIRQ6
    defw isr_birq_7        ; $5C  BIRQ7 (lowest expansion IRQ)
    
    defw isr_null_handler   ; $5E
    defw isr_null_handler   ; $60
    defw isr_null_handler   ; $62
    defw isr_null_handler   ; $64

; =============================================================================
; NMI handler [$0066] — memory protection fault (see mmu.asm)
; =============================================================================
nmi_handler:                ; $0066
    ; todo: memory protection fault handler
    retn

; =============================================================================
; Null ISR — default handler for unassigned IM2 vector slots
; =============================================================================
isr_null_handler:
    ; todo: trap
    reti

; $C300: for the interrupt vectors that land on NOP (00) + JP (C3)
;defs 0xC300 - ASMPC ; will error when we overwrite this marker
;defw isr_null_handler

; $C3F3: for the interrupt vectors that land on DI (F3) + JP (C3)
;defs 0xC3F3 - ASMPC ; will error when we overwrite this marker
;defw isr_null_handler   ; vector $00
