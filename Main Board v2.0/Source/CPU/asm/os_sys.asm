; os_sys.asm  - OS system IO interface

os_sys_init:
    ret

; os_sys_write - writes a byte to an I/O port
; A = value to write
; Destroys: 
os_sys_write:
    ret

; os_sys_read - reads a byte from an I/O port
; Returns: L = value read
; Destroys:
os_sys_read:
    ret

; higher level system IO api

os_sys_rtc_read_date:
    ret
os_sys_rtc_read_time:
    ret

os_sys_uart_write_byte:
    ret
os_sys_uart_read_byte:
    ret

os_sys_cfg_read_8:
    ret
os_sys_cfg_write_8:
    ret
os_sys_cfg_read_16:
    ret
os_sys_cfg_write_16:
    ret
