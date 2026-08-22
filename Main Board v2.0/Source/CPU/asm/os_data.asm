section data_os

include "os_defs.inc"
include "os_task.inc"
;
; OS Data page
;

; 0: task-id (byte)
; Do we also need bank and page-index?

public var_os_mem_page_table
; memory page table keeps track of which pages are allocated to which tasks.
; one entry per page, value is task-id of owning task ($FF if free).
var_os_mem_page_table: defs OS_MEM_PAGE_TABLE_SIZE

public var_os_task_table
; the task table keeps track of all tasks in the system, including their state and other information.
var_os_task_table: defs OS_TASK_TABLE_SIZE
