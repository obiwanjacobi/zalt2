; =============================================================================
; System Entry Functions
; =============================================================================
; NOTE: the RETI is required for the CPLD to track return from supervisor mode.
#include "os_defs.inc"

section code_crt_init

public os_rst_00, os_rst_08, os_rst_10, os_rst_18
public os_rst_20, os_rst_28, os_rst_30, os_rst_38

extern var_os_temp, var_os_task_table

extern os_func_table, fs_func_table, video_func_table
extern audio_func_table, reserved_func_table, debug_func_table
extern os_init
extern mmu_bank_read, mmu_bank_write
extern os_task_current_base_ptr

; boot (warm/cold)
os_rst_00:

    call os_init
    
    ; memory test to determine available extended memory
    ; device initialization
    ; init os subsystems (scheduler etc)
    ; ...
    ei
    reti

; get function id + adjust sp
; switch to os-sp
; switch to os mmu
; index function table with func-id - call function
; switch back to caller-mmu
; switch back to caller-sp

; os-functions entry point. Assumes DI
; Destroys nothing
os_rst_08:
    exx
    ld (var_os_temp+6), hl
    ld hl, os_func_table
    jp os_rst_dispatch

; file-system-functions entry point. Assumes DI
; Destroys nothing
os_rst_10:
    exx
    ld (var_os_temp+6), hl
    ld hl, fs_func_table
    jp os_rst_dispatch

; video-functions entry point. Assumes DI
; Destroys nothing
os_rst_18:
    exx
    ld (var_os_temp+6), hl
    ld hl, video_func_table
    jp os_rst_dispatch

; audio-functions entry point. Assumes DI
; Destroys nothing
os_rst_20:
    exx
    ld (var_os_temp+6), hl
    ld hl, audio_func_table
    jp os_rst_dispatch

; reserved-functions entry point. Assumes DI
; Destroys nothing
os_rst_28:
    exx
    ld (var_os_temp+6), hl
    ld hl, reserved_func_table
    jp os_rst_dispatch

; debug-functions entry point. Assumes DI
; Destroys nothing
os_rst_30:
    exx
    ld (var_os_temp+6), hl
    ld hl, debug_func_table
    jp os_rst_dispatch

; panic and stray code execution handler. Assumes DI
; does not return to caller.
os_rst_38:
    ; read and advance the inline panic code (byte)
    ex (sp), hl             ; HL = inline_byte_addr
    ld e, (hl)              ; E = panic code
    ; we're not going back to the caller, so we don't need to restore HL or SP
    ;inc hl                  ; skip inline byte
    ;ex (sp), hl             ; restore HL; return addr on caller's stack now past byte

    ; TODO: kill task and switch to os task (scheduler)
    ei
    reti

; =============================================================================
; os_rst_dispatch - shared full-context dispatcher (MMU + stack switch)
; =============================================================================
; Entry (via JP, never CALL):
;   exx already done by the RST handler + HL' is saved in var_os_temp
;       other registers (non-') contain the function's parameters (if any)
;   HL' = function table address (array of dw, indexed by inline function byte).
; Stack at entry (caller's SP, top to bottom):
;   [inline_byte_addr]   return address pushed by RST
;   [caller stack...]
; Exit:
;   Caller's MMU and SP restored.
;   All task registers preserved (HL, BC, DE, AF, IX and IY).
;   Returns to the caller past the inline function byte.
; =============================================================================
os_rst_dispatch:
    ; save function table address
    ld (var_os_temp), hl

    ; save DE' in var_os_temp
    ex de, hl
    ld (var_os_temp+4), hl

    ; at this point DE', HL' and the function table address are saved in var_os_temp

    ; read and advance the inline function byte
    ex (sp), hl             ; HL = inline_byte_addr (original HL' is now on top of stack)
    ld e, (hl)              ; C = function id
    inc hl                  ; skip inline byte (does not affect flags)
    ex (sp), hl             ; restore HL; return addr on caller's stack now past byte

    ; store function id in var_os_temp for later use (function table index)
    ld hl, var_os_temp+2
    ld (hl), e

    ; save calling task registers
    push af
    ex af, af'
    push af
    push ix
    push iy
    exx         ; switch to calling registers (function parameters)
    push bc
    push de
    push hl
    exx         ; switch back to alternate register set
    push bc
    
    ; retrieve stored DE' and HL' from var_os_temp
    ld hl, var_os_temp+4
    ld e, (hl)
    inc hl
    ld d, (hl)
    push de     ; DE'
    inc hl
    ld e, (hl)
    inc hl
    ld d, (hl)
    push de     ; HL'

    ; at this point all the caller's registers are saved onto their stack, 
    ;   the function table and the function id are in var_os_temp storage
    ;   function parameters are (still) in the in the other register set

    call os_task_current_base_ptr       ; destroys A, B, DE and HL
    ex de, hl                           ; DE contains TCB pointer of current task

    call mmu_bank_read          ; H = task_id, L = bank  (destroys A, BC)
    ex de, hl
    ; save mmu into current task TCB
    ld (hl), e
    inc hl
    ld (hl), d
    inc hl
    ex de, hl

    ld hl, $0000
    add hl, sp
    ex de, hl
    ; assign SP (in DE) to current task TCB
    ld (hl), e
    inc hl
    ld (hl), d

    ; at this point the current task's TCB has been updated with the current MMU and SP values

    ; retrieve os TCB's MMU value
    ld hl, var_os_task_table        ; os TCB (start of task table)
    ld e, (hl)
    inc hl
    ld d, (hl)
    inc hl
    ex de, hl                       
    call mmu_bank_write         ; task/bank in HL (destroys A, BC, HL)
    
    ; retrieve os TCB's SP value
    ex de, hl
    ld e, (hl)
    inc hl
    ld d, (hl)
    ex de, hl
    ld sp, hl

    ; at this point we're switched to the os-task's MMU and SP

    ; look up function address in table
    ld hl, var_os_temp
    ld e, (hl)              ; DE = function table address
    inc hl
    ld d, (hl)
    inc hl
    ld l, (hl)              ; function id
    ld h, 0
    add hl, hl              ; HL = id * 2
    add hl, de              ; HL = table[func_id]
    ld e, (hl)
    inc hl
    ld h, (hl)
    ld l, e                 ; HL = target function address

    ; push os_rst_return then func_addr; RET jumps to func_addr
    ld de, os_rst_return
    push de
    push hl                 ; func_addr on top of stack   
    exx                     ; switch to function parameters register-set
    ex af, af'
    ret                     ; jump to function; its RET -> os_rst_return

.os_rst_return
    ; switch back to caller's context (not saving OS task context)
    call os_task_current_base_ptr       ; destroys A, B, DE and HL
    ld e, (hl)
    inc hl
    ld d, (hl)
    inc hl
    ex de, hl
    call mmu_bank_write         ; HL= task/bank, destroys A, BC, HL
    ; retrieve caller's SP from TCB
    ex de, hl
    ld e, (hl)
    inc hl
    ld d, (hl)
    ex de, hl
    ld sp, hl

    ; at this point we're switched back to the caller's MMU and SP

    ; restore caller registers
    pop hl
    pop de
    pop bc
    exx
    pop hl
    pop de
    pop bc
    
    pop iy
    pop ix
    pop af
    ex af, af'
    pop af

    ei
    reti    ; use RETI for CPLD to track return from supervisor mode (RST)
