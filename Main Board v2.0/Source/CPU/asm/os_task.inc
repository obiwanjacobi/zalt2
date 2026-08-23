; os_task.inc  - Task definitions and constants
; #include this file in the .asm where you need to reference these definitions.

defc OS_TASK_MAX_COUNT = 16
defc OS_TASK_STRUCT_SIZE = 5
defc OS_TASK_TABLE_SIZE = OS_TASK_MAX_COUNT * OS_TASK_STRUCT_SIZE

; Task structure offsets
defc OS_TASK_STRUCT_OFFSET_LAST_MEMPAGE = 0     ; mmu memory page of the last executed instruction for this task (for context switching) 2 bytes
defc OS_TASK_STRUCT_OFFSET_LAST_SP = 2          ; task's saved SP (for context switching) 2 bytes
defc OS_TASK_STRUCT_OFFSET_STATE = 4            ; state of the task (OS_TASK_STATE_*) 1 byte

; task state values
defc OS_TASK_STATE_FREE = 0         ; task is free and can be allocated
defc OS_TASK_STATE_READY = 1        ; task is ready to run
defc OS_TASK_STATE_RUNNING = 2      ; task is currently running
defc OS_TASK_STATE_WAITING = 3      ; task is waiting for an event or resource
defc OS_TASK_STATE_SUSPENDED = 4    ; task is suspended and cannot run until resumed
defc OS_TASK_STATE_TERMINATED = 5   ; task has been terminated and is no longer active
defc OS_TASK_STATE_PANIC = 6        ; task has encountered a fatal error and cannot continue
defc OS_TASK_STATE_INVALID = 255    ; invalid state, used for error checking
