; os_mem.asm - OS memory management functions

section code_os

#include "./os_defs.asm"

public os_mem_init, os_mem_alloc_page, os_mem_free_page, os_mem_clear, os_mem_fill

extern var_os_mem_page_table

; initializes the memory management subsystem.
; assumes fixed memory size.
; HL = the number of 4k pages available for allocation
os_mem_init:
    ; clear page table
    ld hl, var_os_mem_page_table
    ld bc, OS_MEM_PAGE_TABLE_SIZE
    call os_mem_clear

    ret

; Claims a 4k memory page for a task.
; A = the task-id
; Returns: HL = mapped page address (0 if failed)
; Destroys:
os_mem_alloc_page:
    ; TODO: pass-in a bank and page-index too?
    ; then we can assign it to the task's memory map.
    ret

; Reclaims the 4k memory page from a task.
; A = the task-id
; HL = mapped page address
; Destroys:
os_mem_free_page:
    ; TODO: or pass-in a bank and page-index that is to be freed?
    ret

; Clears memory to zeros.
; HL = start address
; BC = length in bytes (4096 for full page)
; Destroys: de, a
os_mem_clear:
    xor a
    jr os_mem_fill

; Fills memory with a specific value.
; HL = start address
; BC = length in bytes (4096 for full page)
; A = value to fill
; Destroys: de
os_mem_fill:
    ld d, h
    ld e, l
    inc de      ; de points to next byte
    ld (hl), a  ; fill first byte
    ldir        ; HL=Source, DE=Destination, BC=Count
    ret
