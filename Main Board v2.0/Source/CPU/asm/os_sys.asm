; os_sys.asm  - OS system IO interface

section code_os_sysio

#include "os_defs.inc"

os_sys_init:
    ret


; os_sys_rtc_read_date: reads the current date from the RTC and returns it in register A.
; Destroys: BC
os_sys_rtc_read_date:
    ld a, OS_SYS_IO_CMD_RTC_DATE
    ld b, OS_SYS_IO_CMD_PORT
    ld c, 0xFF
    out (c), a
    ld b, OS_SYS_IO_DATA_PORT
    in a, (c)
    ret
; os_sys_rtc_read_time: reads the current time from the RTC and returns it in register A.
; Destroys: BC
os_sys_rtc_read_time:
    ld a, OS_SYS_IO_CMD_RTC_TIME
    ld b, OS_SYS_IO_CMD_PORT
    ld c, 0xFF
    out (c), a
    ld b, OS_SYS_IO_DATA_PORT
    in a, (c)
    ret
; os_sys_rtc_write_date: writes the date in register A to the RTC.
; Destroys: BC
os_sys_rtc_write_date:
    ld a, OS_SYS_IO_CMD_RTC_DATE
    ld b, OS_SYS_IO_CMD_PORT
    ld c, 0xFF
    out (c), a
    ld b, OS_SYS_IO_DATA_PORT
    out (c), a
    ret
; os_sys_rtc_write_time: writes the time in register A to the RTC.
; Destroys: BC
os_sys_rtc_write_time:
    ld a, OS_SYS_IO_CMD_RTC_TIME
    ld b, OS_SYS_IO_CMD_PORT
    ld c, 0xFF
    out (c), a
    ld b, OS_SYS_IO_DATA_PORT
    out (c), a
    ret

; os_sys_uart0_write_byte: writes the byte in register A to UART0.
; Destroys: BC
os_sys_uart0_write_byte:
    ld a, OS_SYS_IO_CMD_CONSOLE0_WR
    ld b, OS_SYS_IO_CMD_PORT
    ld c, 0xFF
    out (c), a
    ld b, OS_SYS_IO_DATA_PORT
    out (c), a
    ret
; os_sys_uart0_read_byte: reads a byte from UART0 and returns it in register A.
; Destroys: BC
os_sys_uart0_read_byte:
    ld a, OS_SYS_IO_CMD_CONSOLE0_RD
    ld b, OS_SYS_IO_CMD_PORT
    ld c, 0xFF
    out (c), a
    ld b, OS_SYS_IO_DATA_PORT
    in a, (c)
    ret

; os_sys_uart1_write_byte: writes the byte in register A to UART1.
; Destroys: BC
os_sys_uart1_write_byte:
    ld a, OS_SYS_IO_CMD_CONSOLE1_WR
    ld b, OS_SYS_IO_CMD_PORT
    ld c, 0xFF
    out (c), a
    ld b, OS_SYS_IO_DATA_PORT
    out (c), a
    ret
; os_sys_uart1_read_byte: reads a byte from UART1 and returns it in register A.
; Destroys: BC
os_sys_uart1_read_byte:
    ld a, OS_SYS_IO_CMD_CONSOLE1_RD
    ld b, OS_SYS_IO_CMD_PORT
    ld c, 0xFF
    out (c), a
    ld b, OS_SYS_IO_DATA_PORT
    in a, (c)
    ret

; TODO: uart0/1 functions that read/write a string of bytes until a null terminator is reached (for console I/O).

os_sys_cfg_read_8:
    ret
os_sys_cfg_write_8:
    ret
os_sys_cfg_read_16:
    ret
os_sys_cfg_write_16:
    ret
