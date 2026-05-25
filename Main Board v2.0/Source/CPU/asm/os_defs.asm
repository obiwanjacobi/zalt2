; os_defs.asm  - OS definitions and constants
; #include this file in the .asm where you need to reference these definitions.

defc OS_MEM_RAM_TOTAL_SIZE = (512 * 1024)
defc OS_MEM_PAGE_COUNT = OS_MEM_RAM_TOTAL_SIZE / (4 * 1024) ; 512kB in (128) 4k pages
defc OS_MEM_STRUCT_SIZE = 1
defc OS_MEM_PAGE_TABLE_SIZE = OS_MEM_PAGE_COUNT * OS_MEM_STRUCT_SIZE

defc OS_ROM_NULL_PAGE = 0x00F0
