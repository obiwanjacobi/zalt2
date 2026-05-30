; os_defs.inc  - OS definitions and constants
; #include this file in the .asm where you need to reference these definitions.

; Memory layout definitions
defc OS_MEM_RAM_TOTAL_SIZE = (512 * 1024)
defc OS_MEM_PAGE_COUNT = OS_MEM_RAM_TOTAL_SIZE / (4 * 1024) ; 512kB in (128) 4k pages
defc OS_MEM_STRUCT_SIZE = 1
defc OS_MEM_PAGE_TABLE_SIZE = OS_MEM_PAGE_COUNT * OS_MEM_STRUCT_SIZE

; Memory map:
;   ROM 512 kB : 0x1F80000 .. 0x1FFFFFF  MA[24:19] = "111111"
;   RAM 512 kB : 0x1F00000 .. 0x1F7FFFF  MA[24:19] = "111110"
defc ROM_START = 0x1F80000
defc RAM_START = 0x1F00000

defc OS_ROM_NULL_PAGE = 0x00F0

; keep os-stack on page0 ($0000-$0FFF)
defc OS_TASK_STACK_TOP = 0x1000

; System IO interface definitions (hi-byte)
defc OS_SYS_IO_CMD_PORT = 0x06
defc OS_SYS_IO_DATA_PORT = 0x07
; System IO command definitions
defc OS_SYS_IO_CMD_RTC_DATE = 0x01
defc OS_SYS_IO_CMD_RTC_TIME = 0x02
defc OS_SYS_IO_CMD_CONSOLE0_RD = 0x10
defc OS_SYS_IO_CMD_CONSOLE0_WR = 0x12
defc OS_SYS_IO_CMD_CONSOLE1_RD = 0x11
defc OS_SYS_IO_CMD_CONSOLE1_WR = 0x13

; Panic Codes (RST38)
defc PANIC_RING_BUFFER_PUSH_WHEN_FULL = 0x01
defc PANIC_RING_BUFFER_POP_WHEN_EMPTY = 0x02
defc PANIC_STRAY_CODE_EXECUTION = 0xFF