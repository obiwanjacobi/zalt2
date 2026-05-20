; =============================================================================
; System Entry Functions
; =============================================================================
; NOTE: the RETI is required for the CPLD to track return from supervisor mode.

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
