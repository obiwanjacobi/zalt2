; =============================================================================
; System Entry Functions
; =============================================================================
; NOTE: the RETI is required for the CPLD to track return from supervisor mode.
; TODO: An interrupt during RST execution will confuse RETI tracking. So RST should DI.

section code_crt_init

public rst_00, rst_08, rst_10, rst_18
public rst_20, rst_28, rst_30, rst_38

extern os_func_table, fs_func_table, video_func_table
extern audio_func_table, reserved_func_table, debug_func_table

; boot (warm/cold)
rst_00:
    xor a
    ; init registers
    ; initialize mmu (os-startup)
    ; memory test to determine available memory
    ; device initialization
    ; init os subsystems (scheduler etc)
    ; ...
    ei
    reti

rst_08:
    ld bc, os_func_table
    call rst_dispatch
    ei
    reti

rst_10:
    ld bc, fs_func_table
    call rst_dispatch
    ei
    reti

rst_18:
    ld bc, video_func_table
    call rst_dispatch
    ei
    reti

rst_20:
    ld bc, audio_func_table
    call rst_dispatch
    ei
    reti

rst_28:
    ld bc, reserved_func_table
    call rst_dispatch
    ei
    reti

rst_30:
    ld bc, debug_func_table
    call rst_dispatch
    ei
    reti

; stray code execution
rst_38:
    ei
    reti

; =============================================================================
; rst_dispatch - shared dispatcher called by each RST handler
; =============================================================================
; Entry:
;   BC  = function address table (array of dw, indexed by function byte)
;   Stack (top to bottom):
;     [ret_to_rst]       return address pushed by CALL rst_dispatch
;     [inline_byte_addr] return address pushed by RST = addr of function byte
;     [caller stack...]
;   HL, DE, A = caller parameters; passed unchanged to dispatched function.
; Exit:
;   Dispatched function entered directly (via RET trick).
;   Function must end with RET; this returns to the RST handler's RETI.
;   RETI returns to the caller past the inline function byte.
;   BC clobbered. All other registers intact.
; =============================================================================
rst_dispatch:
    exx                     ; save caller's HL/BC/DE (incl. table ptr) to alt set
    ex af, af'              ; save caller's A

    ; TODO: Switch to OS Task/Bank memory layout and reassign SP
    ; switch back after dispatching and executing the function.

    ; SP+0 = ret_to_rst, SP+2 = inline_byte_addr
    ld hl, 2
    add hl, sp              ; HL -> stack slot holding inline_byte_addr
    ld e, (hl)
    inc hl
    ld d, (hl)              ; DE = inline_byte_addr
    dec hl
    ld a, (de)              ; A = function id
    inc de                  ; DE = inline_byte_addr + 1
    ld (hl), e              ; write back: advance past function byte
    inc hl
    ld (hl), d
    ; stack: [ret_to_rst | inline_byte_addr+1 | caller...]

    exx                     ; restore caller's HL/DE, BC = table; A = function id
    ; (EXX does not touch AF; function id survives in A)

    ;cp MAX_FUNC_ID          ; how to get max-id per func-table (BC)?
    ;jr nc, _dispatch_invalid

    push hl                 ; save caller's HL
    ld l, a
    ld h, 0
    add hl, hl              ; HL = function_id * 2
    add hl, bc              ; HL = &table[function_id]
    ld a, (hl)
    inc hl
    ld h, (hl)
    ld l, a                 ; HL = function address

    ex af, af'              ; restore caller's A
    ex (sp), hl             ; [SP] = function address, HL = caller's HL restored
    ret                     ; jump to function — stack: [ret_to_rst | inline_byte_addr+1 | ...]
                            ; function RETs -> ret_to_rst -> RST handler RETI -> caller+1


rst_simple_example:
    ex (sp), hl             ; HL = address of inline function byte
    ld a, (hl)              ; A = function id
    inc hl                  ; skip inline byte (return goes past it)
    ex (sp), hl             ; restore HL, update return address on stack
    ; --- dispatch ---
    ld l, a
    ld h, 0
    add hl, hl              ; HL = id * 2 (index into word table)
    ld de, os_func_table
    add hl, de              ; HL = &os_func_table[id]
    ld a, (hl)
    inc hl
    ld h, (hl)
    ld l, a                 ; HL = target function address
    jp (hl)
