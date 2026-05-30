section data_os

include "os_defs.inc"
;
; OS Data page
;

; 0: task-id (byte)
; Do we also need bank and page-index?

public var_os_mem_page_table
; memory page table keeps track of which pages are allocated to which tasks.
; one entry per page, value is task-id of owning task (0 if free).
var_os_mem_page_table: defs OS_MEM_PAGE_TABLE_SIZE

; I dont understand how to use defvars in assembly...
; os_task struct
defvars 0
{
    task_mmu     ds.w    1   ; task_id:bank of active task (for context switching); 0 if OS task active
    task_sp      ds.w    1   ; task's saved SP (for context switching)
}
    ;task_next    ds.w    1   ; pointer to next task in list (0 if end of list)
    ;task_entry_point  ds.w    1   ; task's entry point (for starting task)
    ;list allocated memory pages
