; os_data0.asm  - page0 data

section code_crt_init

public var_os_task_current
; Current active task id (0 = os)
var_os_task_current: defs 1

; TEMP
public var_os_caller_mmu, var_os_caller_sp
; stores caller context when calling into the OS.
var_os_caller_mmu: defs 2       ; mmu taskid:bank
var_os_caller_sp: defs 2        ; stack pointer

; system IO status byte (bitfield)
public var_os_sys_io_status
var_os_sys_io_status: defb 0
