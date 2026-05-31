; lib_api.asm - C-callable API wrappers for assembly library functions
; This file provides C-callable wrappers for assembly library functions,
; allowing them to be called from C code.

extern mem_fill, mem_clear
extern lib_ring_buffer_construct, lib_ring_buffer_canpush, lib_ring_buffer_canpop, lib_ring_buffer_push, lib_ring_buffer_pop
extern lib_ring_buffer8_construct, lib_ring_buffer8_canpush, lib_ring_buffer8_canpop, lib_ring_buffer8_push, lib_ring_buffer8_pop
extern lib_ring_buffer16_construct, lib_ring_buffer16_canpush, lib_ring_buffer16_canpop, lib_ring_buffer16_push, lib_ring_buffer16_pop

public _Memory_Fill, _Memory_Clear
public _RingBuffer_Construct, _RingBuffer_CanPush, _RingBuffer_CanPop, _RingBuffer_Push, _RingBuffer_Pop
public _RingBuffer8_Construct, _RingBuffer8_CanPush, _RingBuffer8_CanPop, _RingBuffer8_Push, _RingBuffer8_Pop
public _RingBuffer16_Construct, _RingBuffer16_CanPush, _RingBuffer16_CanPop, _RingBuffer16_Push, _RingBuffer16_Pop

; C callee: void Memory_Fill(void* memory, uint16_t size, uint8_t value)
_Memory_Fill:
    pop de  ; return address
    pop hl  ; dest
    pop bc  ; size
    pop af   ; value
    push de  ; restore return address
    jp mem_fill

; C callee: void Memory_Clear(void* memory, uint16_t size)
_Memory_Clear:
    pop de  ; return address
    pop hl  ; dest
    pop bc  ; size
    push de  ; restore return address
    jp mem_clear

; C callee: void* RingBuffer_Construct(void* rb, uint16_t size)
_RingBuffer_Construct:
    pop de      ; return address
    pop hl
    pop bc
    push hl     ; save buffer address
    push de
    call lib_ring_buffer_construct
    pop hl
    ret

; C callee: uint8_t RingBuffer_CanPush(void* rb)
_RingBuffer_CanPush:
    pop de      ; return address
    pop hl
    push de
    call lib_ring_buffer_canpush   ; Z=0 => true, Z=1 => false
    ld l, 0
    jr z, _RingBuffer_CanPush_done
    inc l
._RingBuffer_CanPush_done
    ret

; C callee: uint8_t RingBuffer_CanPop(void* rb)
_RingBuffer_CanPop:
    pop de      ; return address
    pop hl
    push de
    call lib_ring_buffer_canpop   ; Z=0 => true, Z=1 => false
    ld l, 0
    jr z, _RingBuffer_CanPop_done
    inc l
._RingBuffer_CanPop_done
    ret

; C callee: void RingBuffer_Push(void* rb, uint8_t value)
_RingBuffer_Push:
    pop de      ; return address
    pop hl
    pop af
    push de
    jp lib_ring_buffer_push

; C callee: uint8_t RingBuffer_Pop(void* rb)
_RingBuffer_Pop:
    pop de      ; return address
    pop hl
    push de
    call lib_ring_buffer_pop
    ld l, a
    ret

; C callee: void* RingBuffer8_Construct(void* rb, uint8_t size)
_RingBuffer8_Construct:
    pop de      ; return address
    pop hl
    pop bc
    push hl
    push de
    call lib_ring_buffer8_construct
    pop hl
    ret

; C callee: uint8_t RingBuffer8_CanPush(void* rb)
_RingBuffer8_CanPush:
    pop de      ; return address
    pop hl
    push de
    call lib_ring_buffer8_canpush  ; Z=0 => true, Z=1 => false
    ld l, 0
    jr z, _RingBuffer8_CanPush_done
    inc l
._RingBuffer8_CanPush_done
    ret

; C callee: uint8_t RingBuffer8_CanPop(void* rb)
_RingBuffer8_CanPop:
    pop de      ; return address
    pop hl
    push de
    call lib_ring_buffer8_canpop   ; Z=0 => true, Z=1 => false
    ld l, 0
    jr z, _RingBuffer8_CanPop_done
    inc l
._RingBuffer8_CanPop_done
    ret

; C callee: void RingBuffer8_Push(void* rb, uint8_t value)
_RingBuffer8_Push:
    pop de      ; return address
    pop hl
    pop af
    push de
    jp lib_ring_buffer8_push

; C callee: uint8_t RingBuffer8_Pop(void* rb)
_RingBuffer8_Pop:
    pop de      ; return address
    pop hl
    push de
    call lib_ring_buffer8_pop
    ld l, a
    ret

; C callee: void* RingBuffer16_Construct(void* rb, uint16_t size)
_RingBuffer16_Construct:
    pop de      ; return address
    pop hl
    pop bc
    push de
    push hl
    call lib_ring_buffer16_construct
    pop hl
    ret

; C callee: uint8_t RingBuffer16_CanPush(void* rb)
_RingBuffer16_CanPush:
    pop de      ; return address
    pop hl
    push de
    call lib_ring_buffer16_canpush  ; Z=0 => true, Z=1 => false
    ld l, 0
    jr z, _RingBuffer16_CanPush_done
    inc l
._RingBuffer16_CanPush_done
    ret

; C callee: uint8_t RingBuffer16_CanPop(void* rb)
_RingBuffer16_CanPop:
    pop de      ; return address
    pop hl
    push de
    call lib_ring_buffer16_canpop   ; Z=0 => true, Z=1 => false
    ld l, 0
    jr z, _RingBuffer16_CanPop_done
    inc l
._RingBuffer16_CanPop_done
    ret

; C callee: void RingBuffer16_Push(void* rb, uint8_t value)
_RingBuffer16_Push:
    pop de      ; return address
    pop hl
    pop af
    push de
    jp lib_ring_buffer16_push

; C callee: uint8_t RingBuffer16_Pop(void* rb)
_RingBuffer16_Pop:
    pop de      ; return address
    pop hl
    push de
    call lib_ring_buffer16_pop
    ld l, a
    ret

