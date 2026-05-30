; os_mem.asm - OS memory management functions

section code_os

#include "os_defs.inc"

public os_mem_init, os_mem_alloc_page, os_mem_free_page

extern mem_clear
extern var_os_mem_page_table

; initializes the memory management subsystem.
; assumes fixed memory size.
; HL = the number of 4k pages available for allocation
os_mem_init:
    ; clear page table
    ld hl, var_os_mem_page_table
    ld bc, OS_MEM_PAGE_TABLE_SIZE
    call mem_clear
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
