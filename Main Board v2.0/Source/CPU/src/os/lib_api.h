#ifndef __OS_API_H__
#define __OS_API_H__

#include "types.h"

void Api(Memory_Fill(ptr_t dest, uint16_t size, uint8_t value));
void Api(Memory_Clear(ptr_t dest, uint16_t size));

// Compile-time dispatch to the fastest Memory_Clear/Memory_Fill for dest's
// size. dest must be the object itself (not a pointer) - e.g. MEM_INIT(myStruct).
// Mirrors asm/lib_mem.inc's MEM_CLEAR/MEM_FILL macros. sizeof(dest) is always
// a compile-time constant, so the compiler folds this down to a single call.
#define MEM_CLEAR(dest) \
    do { \
        if (sizeof(dest) == 1) *(uint8_t*)(ptr_t)&(dest) = 0; \
        else if (sizeof(dest) == 2) Memory_Clear2((ptr_t)&(dest)); \
        else if (sizeof(dest) == 3) Memory_Clear3((ptr_t)&(dest)); \
        else if (sizeof(dest) == 4) Memory_Clear4((ptr_t)&(dest)); \
        else Memory_Clear((ptr_t)&(dest), sizeof(dest)); \
    } while (0)

#define MEM_FILL(dest, value) \
    do { \
        if (sizeof(dest) == 1) *(uint8_t*)(ptr_t)&(dest) = (value); \
        else if (sizeof(dest) == 2) Memory_Fill2((ptr_t)&(dest), (value)); \
        else if (sizeof(dest) == 3) Memory_Fill3((ptr_t)&(dest), (value)); \
        else if (sizeof(dest) == 4) Memory_Fill4((ptr_t)&(dest), (value)); \
        else Memory_Fill((ptr_t)&(dest), sizeof(dest), (value)); \
    } while (0)

#ifdef DEBUG
    #define MEM_INIT(dest)  MEM_FILL(dest, 0xFF)
#else
    #define MEM_INIT(dest)  MEM_CLEAR(dest)
#endif

typedef ptr_t ring_buffer_t;
ring_buffer_t Api(RingBuffer_Construct(ptr_t rb, uint16_t size));
uint8_t Api(RingBuffer_CanPush(ring_buffer_t rb));
uint8_t Api(RingBuffer_CanPull(ring_buffer_t rb));
void Api(RingBuffer_Push(ring_buffer_t rb, uint8_t value));
uint8_t Api(RingBuffer_Pop(ring_buffer_t rb));

//   - data_capacity must be one of: 1, 2, 4, 8, 16, 32, 64, 128.
//   - total reserved bytes passed to construct = data_capacity + 3.
ring_buffer_t Api(RingBuffer8_Construct(ptr_t rb, uint8_t size));
uint8_t Api(RingBuffer8_CanPush(ring_buffer_t rb));
uint8_t Api(RingBuffer8_CanPop(ring_buffer_t rb));
void Api(RingBuffer8_Push(ring_buffer_t rb, uint8_t value));
uint8_t Api(RingBuffer8_Pop(ring_buffer_t rb));

//   - data_capacity must be a power of 2 (1, 2, 4, 8, 16, 32, 64, 128, 256, 1024, 2048, 4096, ...).
//   - total reserved bytes passed to construct = data_capacity + 6.
ring_buffer_t Api(RingBuffer16_Construct(ptr_t rb, uint16_t size));
uint8_t Api(RingBuffer16_CanPush(ring_buffer_t rb));
uint8_t Api(RingBuffer16_CanPop(ring_buffer_t rb));
void Api(RingBuffer16_Push(ring_buffer_t rb, uint8_t value));
uint8_t Api(RingBuffer16_Pop(ring_buffer_t rb));


#endif // __OS_API_H__
