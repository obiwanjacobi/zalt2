; os_sys.asm  - OS system IO interface

section code_os_sysio

#include "os_defs.inc"

public os_sys_init
public os_sys_rtc_read_date, os_sys_rtc_read_time, os_sys_rtc_write_date, os_sys_rtc_write_time
public os_sys_uart0_write_byte, os_sys_uart0_read_byte
public os_sys_uart1_write_byte, os_sys_uart1_read_byte

os_sys_init:
    ret

; os_sys_rtc_read_date: reads the current date from the RTC and returns it in register A.
; Destroys: A, BC
os_sys_rtc_read_date:
    ld a, OS_SYS_IO_CMD_RTC_DATE
    jp os_sys_command_read_byte
; os_sys_rtc_read_time: reads the current time from the RTC and returns it in register A.
; Destroys: A, BC
os_sys_rtc_read_time:
    ld a, OS_SYS_IO_CMD_RTC_TIME
    jp os_sys_command_read_byte
; os_sys_rtc_write_date: writes the date in register D to the RTC.
; Destroys: A, BC
os_sys_rtc_write_date:
    ld a, OS_SYS_IO_CMD_RTC_DATE
    jp os_sys_command_write_byte
; os_sys_rtc_write_time: writes the time in register D to the RTC.
; Destroys: A, BC
os_sys_rtc_write_time:
    ld a, OS_SYS_IO_CMD_RTC_TIME
    jp os_sys_command_write_byte

; os_sys_uart0_write_byte: writes the byte in register D to UART0.
; Destroys: A, BC
os_sys_uart0_write_byte:
    ld a, OS_SYS_IO_CMD_CONSOLE0_WR
    jp os_sys_command_write_byte
; os_sys_uart0_read_byte: reads a byte from UART0 and returns it in register A.
; Destroys: A, BC
os_sys_uart0_read_byte:
    ld a, OS_SYS_IO_CMD_CONSOLE0_RD
    jp os_sys_command_read_byte

; os_sys_uart1_write_byte: writes the byte in register D to UART1.
; Destroys: A, BC
os_sys_uart1_write_byte:
    ld a, OS_SYS_IO_CMD_CONSOLE1_WR
    jp os_sys_command_write_byte
; os_sys_uart1_read_byte: reads a byte from UART1 and returns it in register A.
; Destroys: A, BC
os_sys_uart1_read_byte:
    ld a, OS_SYS_IO_CMD_CONSOLE1_RD
    jp os_sys_command_read_byte

; TODO: uart0/1 functions that read/write a string of bytes until a null terminator is reached (for console I/O).

os_sys_cfg_read_8:
    ret
os_sys_cfg_write_8:
    ret
os_sys_cfg_read_16:
    ret
os_sys_cfg_write_16:
    ret

; --- helpers -----------------------------------------------------------------

; os_sys_command_read_byte: sends the command byte in register A to the OS system IO interface and returns the response in register A.
; Destroys: A, BC
os_sys_command_read_byte:
    ld b, OS_SYS_IO_CMD_PORT
    ld c, 0xFF
    out (c), a
    ld b, OS_SYS_IO_DATA_PORT
    in a, (c)
    ret

;sends the command byte in register A to the OS system IO interface and writes the data byte in register D to the OS system IO interface.
; Destroys: A, BC
os_sys_command_write_byte:
    ld b, OS_SYS_IO_CMD_PORT
    ld c, 0xFF
    out (c), a
    ld b, OS_SYS_IO_DATA_PORT
    out (c), d
    ret
