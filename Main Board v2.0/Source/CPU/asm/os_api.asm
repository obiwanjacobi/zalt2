; os_api.h  - OS public API entry point (calls RSTs)
; for now, just dummy examples

section code_compiler

public _os_func, _os_struct_func

_os_func:
    ret

_os_struct_func:
    ret

; OS-provided helper functions
extern os_mem_fill, os_mem_clear
public _Memory_Fill, _Memory_Clear
_Memory_Fill:
    pop de  ; return address
    pop hl  ; dest
    pop bc  ; size
    pop af   ; value
    push de  ; restore return address
    jp os_mem_fill

_Memory_Clear:
    pop de  ; return address
    pop hl  ; dest
    pop bc  ; size
    push de  ; restore return address
    jp os_mem_clear
