; =============================================================================
; System Entry Functions
; =============================================================================
; NOTE: the RETI is required for the CPLD to track return from supervisor mode.
#include "os_defs.inc"

section code_crt_init

public os_rst_00, os_rst_08, os_rst_10, os_rst_18
public os_rst_20, os_rst_28, os_rst_30, os_rst_38

extern var_os_caller_mmu, var_os_caller_sp

extern os_func_table, fs_func_table, video_func_table
extern audio_func_table, reserved_func_table, debug_func_table
extern os_init
extern mmu_bank_read, mmu_bank_write

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
; Destroys BC', HL'
os_rst_08:
    exx
    ld bc, os_func_table
    jp os_rst_dispatch

; file-system-functions entry point. Assumes DI
; Destroys BC', HL'
os_rst_10:
    exx
    ld bc, fs_func_table
    jp os_rst_dispatch

; video-functions entry point. Assumes DI
; Destroys BC', HL'
os_rst_18:
    exx
    ld bc, video_func_table
    jp os_rst_dispatch

; audio-functions entry point. Assumes DI
; Destroys BC', HL'
os_rst_20:
    exx
    ld bc, audio_func_table
    jp os_rst_dispatch

; reserved-functions entry point. Assumes DI
; Destroys BC', HL'
os_rst_28:
    exx
    ld bc, reserved_func_table
    jp os_rst_dispatch

; debug-functions entry point. Assumes DI
; Destroys BC', HL'
os_rst_30:
    exx
    ld bc, debug_func_table
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
;   exx already done by the RST handler — caller regs in alt set.
;   BC  = function table address (array of dw, indexed by inline function byte).
; Stack at entry (caller's SP, top to bottom):
;   [inline_byte_addr]   return address pushed by RST
;   [caller stack...]
; Exit:
;   Caller's MMU and SP restored.
;   All task registers preserved (HL, BC, DE, AF, IX and IY).
;   Returns to the caller past the inline function byte.
; =============================================================================
os_rst_dispatch:
    ; read and advance the inline function byte
    ex (sp), hl             ; HL = inline_byte_addr
    ld e, (hl)              ; E = function id
    inc hl                  ; skip inline byte (does not affect flags)
    ex (sp), hl             ; restore HL; return addr on caller's stack now past byte

    ; save calling task registers
    exx
    push af
    push bc
    push de
    push hl
    push ix
    push iy

    call os_task_current_base_ptr       ; hl contains base pointer of current task

    ; TODO: call os_task_switch_to_os to switch to os-task context (MMU + stack)
    ; save caller's MMU and SP

    ; switch stacks
    ld (var_os_caller_sp), sp
    ld sp, OS_TASK_STACK_TOP

    push bc                 ; save table ptr on OS stack

    ; switch mmu to os-task
    call mmu_bank_read          ; H = task_id, L = bank  (destroys A, BC)
    ld   (var_os_caller_mmu), hl
    ld   hl, 0
    call mmu_bank_write         ; (destroys A, BC)

    ; look up function address in table
    pop bc                  ; restore table ptr
    ld l, e                 ; function id
    ld h, 0
    add hl, hl              ; HL = id * 2
    add hl, bc              ; HL = &table[func_id]
    ld a, (hl)
    inc hl
    ld h, (hl)
    ld l, a                 ; HL = target function address

    ; push os_rst_return then func_addr; RET jumps to func_addr
    ld bc, os_rst_return
    push bc
    push hl                 ; func_addr on top of stack   
    ret                     ; jump to function; its RET -> os_rst_return

.os_rst_return
    ; switch back to caller's context
    ld   hl, (var_os_caller_mmu)
    call mmu_bank_write

    ld sp, (var_os_caller_sp)
    ; restore caller registers
    pop iy
    pop ix
    pop hl
    pop de
    pop bc
    pop af

    ei
    reti    ; use RETI for CPLD to track return from supervisor mode (RST)
