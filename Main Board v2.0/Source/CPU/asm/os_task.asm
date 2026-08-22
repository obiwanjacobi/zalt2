section code_crt_init

#include "os_defs.inc"
#include "os_task.inc"

extern mmu_map_enable
extern mmu_map_write
extern mmu_bank_read
extern mmu_bank_write
extern os_mem_init

extern mem_clear

public os_init
; =============================================================================
; os_init
; Initializes OS startup code.
; =============================================================================
os_init:
    xor a
    ld i, a     ; set interupt vector table base to $00 (vectors at $0000 / page0)
    im 2

    ; - copy page0 from ROM to RAM (not now)
    ;    assuming we need data in page0 - perhaps not if we always switch task

    ; - set up MMU mapping for os
    call os_mmu_init

    ; can run in os-task context
    call os_mem_init

    ; initialize task table and memory page table
    call os_task_init
    ret

; Identity-map the first 16 Z80 pages (full 64KB) to task 0, bank 0 in RAM.
; Physical RAM base: 0x1F00000 → page_frame = 0x1F00
; MMU_MP_OS bit is set on all pages.
;   D = 0x1F  (page_frame high byte, constant: MA[24:20] = 11111b, RAM region)
;   E = N     (page_frame low byte for page N: MA[19:12] = N)
; Conveniently, page_index = N = E, so A = E each iteration.
os_mmu_init:
    ; TODO: we should enable after initialization is done (change CPLD).
    call mmu_map_enable         ; enable mapping SRAMs before any access

    ld   d, $3F                 ; page_frame high byte (RAM region, constant) + OS MP-bit
    xor  a
    ld   e, a                   ; E = 0 (page_frame low byte, starts at page 0)
    ld   b, 16                  ; 16 pages to map (Z80 pages 0..15)

.mmu_init_loop
    push bc                     ; preserve loop counter
    ld   hl, 0                  ; bank (L) = 0 ; task_id (H) = 0  (mmu_map_write destroys HL)
    ld   a, e                   ; page_index = N (= E, since page_frame low = page_index here)
    call mmu_map_write          ; destroys A, BC, HL
    pop  bc
    inc  e                      ; advance to next page
    djnz mmu_init_loop
    ret


os_task_init:
    ld hl, var_os_task_current
    ld (hl), 0                  ; current task = 0 (os)

    ; clear task table
    ld hl, var_os_task_table
    ld bc, OS_TASK_TABLE_SIZE
    call mem_clear

    ; clear memory page table
    ld hl, var_os_mem_page_table
    ld bc, OS_MEM_PAGE_TABLE_SIZE
    call mem_clear

    ret

public os_task_create, os_task_destroy, os_task_switch_to, os_task_switch_to_os
; TODO: task scheduler and context switching.

; creates a new task and returns its task_id in A (0 = os, 1..N = user tasks)
os_task_create:
    ret
; destroys a task and frees its resources (task_id in A)
os_task_destroy:
    ret
; switches to a task context (task_id in A)
os_task_switch_to:
    ret

; switches to the os-task
os_task_switch_to_os:
    ld hl, var_os_task_current

    ; debug: should never happen
    ; check if already in os-task context (task_id = 0)
    xor a
    cp (hl)
    ret z

    ld a, (hl)              ; A = current task_id
    call os_task_base_ptr   ; hl = base pointer of current task

    ; swicth!

    ret

; returns the base pointer in HL of the current task
; Destroys: A, B, DE, HL
os_task_current_base_ptr:
    ld a, (var_os_task_current)
; returns the base pointer in HL of the task (task_id in A)
; Destroys: B, DE, HL
os_task_base_ptr:
    ld hl, var_os_task_table
    
    ; debug: should never happen
    cp 0        ; os-task (task_id = 0)
    ret z

    ld b, a     ; counter
    ld de, OS_TASK_TABLE_ENTRY_SIZE

.os_task_base_ptr_loop
    add hl, de
    djnz os_task_base_ptr_loop

    ret
