extern mem_fill, mem_clear
extern lib_ring_buffer_construct, lib_ring_buffer_canpush, lib_ring_buffer_canpull
extern lib_ring_buffer_push, lib_ring_buffer_pop
extern lib_ring_buffer8_construct, lib_ring_buffer8_canpush, lib_ring_buffer8_canpop
extern lib_ring_buffer8_push, lib_ring_buffer8_pop

public _Memory_Fill, _Memory_Clear
public _RingBuffer_Construct, _RingBuffer_CanPush, _RingBuffer_CanPull
public _RingBuffer_Push, _RingBuffer_Pop
public _RingBuffer8_Construct, _RingBuffer8_CanPush, _RingBuffer8_CanPop
public _RingBuffer8_Push, _RingBuffer8_Pop

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

; C callee: void RingBuffer_Construct(void* rb, uint16_t size)
_RingBuffer_Construct:
    pop de
    pop hl
    pop bc
    push de
    jp lib_ring_buffer_construct

; C callee: uint8_t RingBuffer_CanPush(void* rb)
_RingBuffer_CanPush:
    pop de
    pop hl
    push de
    call lib_ring_buffer_canpush   ; Z=0 => true, Z=1 => false
    ld l, 0
    jr z, _RingBuffer_CanPush_done
    inc l
._RingBuffer_CanPush_done
    ret

; C callee: uint8_t RingBuffer_CanPull(void* rb)
_RingBuffer_CanPull:
    pop de
    pop hl
    push de
    call lib_ring_buffer_canpull   ; Z=0 => true, Z=1 => false
    ld l, 0
    jr z, _RingBuffer_CanPull_done
    inc l
._RingBuffer_CanPull_done
    ret

; C callee: void RingBuffer_Push(void* rb, uint8_t value)
_RingBuffer_Push:
    pop de
    pop hl
    pop af
    push de
    jp lib_ring_buffer_push

; C callee: uint8_t RingBuffer_Pop(void* rb)
_RingBuffer_Pop:
    pop de
    pop hl
    push de
    call lib_ring_buffer_pop
    ld l, a
    ret

; C callee: void RingBuffer8_Construct(void* rb, uint16_t size)
_RingBuffer8_Construct:
    pop de
    pop hl
    pop bc
    push de
    jp lib_ring_buffer8_construct

; C callee: uint8_t RingBuffer8_CanPush(void* rb)
_RingBuffer8_CanPush:
    pop de
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
    pop de
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
    pop de
    pop hl
    pop af
    push de
    jp lib_ring_buffer8_push

; C callee: uint8_t RingBuffer8_Pop(void* rb)
_RingBuffer8_Pop:
    pop de
    pop hl
    push de
    call lib_ring_buffer8_pop
    ld l, a
    ret
