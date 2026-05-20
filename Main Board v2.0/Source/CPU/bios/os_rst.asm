; =============================================================================
; System Entry Functions
; =============================================================================
; NOTE: the RETI is required for the CPLD to track return from supervisor mode.

section code_crt_init

public rst_00, rst_08, rst_10, rst_18
public rst_20, rst_28, rst_30, rst_38

; boot (warm/cold)
rst_00:
    xor a
    reti

rst_08:
    reti

rst_10:
    reti

rst_18:
    reti

rst_20:
    reti

rst_28:
    reti

rst_30:
    reti

; stray code execution
rst_38:
    reti
