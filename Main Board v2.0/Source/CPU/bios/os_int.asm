; =============================================================================
; System interrupt handlers
; =============================================================================

section code_crt_init

public isr_sysint_1, isr_sysint_2, isr_sysint_3, isr_sysint_4
public isr_sysint_5, isr_sysint_6, isr_sysint_7
public isr_birq_0, isr_birq_1, isr_birq_2, isr_birq_3
public isr_birq_4, isr_birq_5, isr_birq_6, isr_birq_7

; System Tick Timer
isr_sysint_1:
    ; call Task Scheduler
    ei
    reti

; Keyboard
isr_sysint_2:
    ei
    reti

; User Console (console 0)
isr_sysint_3:
    ei
    reti

; Programmable Timer 0
isr_sysint_4:
    ei
    reti

; Debug Console (console 1)
isr_sysint_5:
    ei
    reti

; Programmable Timer 1
isr_sysint_6:
    ei
    reti

; Protocol Signal
isr_sysint_7:
    ei
    reti

; =============================================================================
; Device interrupt handlers
; =============================================================================

; Smart Device Card #1
isr_birq_0:
    ei
    reti

; Smart Device Card #2
isr_birq_1:
    ei
    reti

; Smart Device Card #3
isr_birq_2:
    ei
    reti

; Smart Device Card #4
isr_birq_3:
    ei
    reti

; Smart Device Card #5
isr_birq_4:
    ei
    reti

; Smart Device Card #6
isr_birq_5:
    ei
    reti

; Smart Device Card #7
isr_birq_6:
    ei
    reti

; Smart Device Card #8
isr_birq_7:
    ei
    reti
