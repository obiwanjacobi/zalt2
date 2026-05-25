; os_stack.asm  - page0 data

section code_crt_init

public var_os_caller_mmu, var_os_caller_sp
; stores caller context when calling into the OS.
var_os_caller_mmu: defs 2       ; mmu taskid:bank
var_os_caller_sp: defs 2        ; stack pointer

public OS_TASK_STACK_TOP
; keep os-stack on page0 ($0000-$0FFF)
defc OS_TASK_STACK_TOP = $1000
