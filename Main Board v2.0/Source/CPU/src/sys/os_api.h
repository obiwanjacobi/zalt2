#ifndef __OS_API_H__
#define __OS_API_H__

#include <stdint.h>

// Entry Points for OS functions

uint8_t os_func(uint16_t arg) __z88dk_fastcall;

typedef struct
{
    uint16_t arg1;
    uint16_t arg2;
} os_func_args;
uint16_t os_struct_func(const os_func_args* args) __z88dk_fastcall;

#endif /* __OS_API_H__ */
