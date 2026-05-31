#ifndef __OS_API_H__
#define __OS_API_H__

#include "types.h"

void Api(Memory_Fill(ptr_t dest, uint16_t size, uint8_t value));
void Api(Memory_Clear(ptr_t dest, uint16_t size));

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
