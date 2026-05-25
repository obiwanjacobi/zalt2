section data_os

;
; OS Data page
;

public var_os_caller_mmu
var_os_caller_mmu: defs 2                  ; calling task's MMU bank

public var_os_caller_sp
var_os_caller_sp: defs 2                  ; calling task's SP

; os_task struct
defvars 0
{
    task_mmu     ds.w    1   ; task_id:bank of active task (for context switching); 0 if OS task active
    task_sp      ds.w    1   ; task's saved SP (for context switching)
}
    ;task_next    ds.w    1   ; pointer to next task in list (0 if end of list)
    ;task_entry_point  ds.w    1   ; task's entry point (for starting task)
    ;list allocated memory pages
