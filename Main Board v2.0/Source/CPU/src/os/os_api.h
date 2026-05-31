#ifndef __OS_API_H__
#define __OS_API_H__

#include "types.h"

// Entry Points for OS functions

uint8_t FastCall(os_func)(uint16_t arg);

typedef struct
{
    uint16_t arg1;
    uint16_t arg2;
} os_func_args;
uint16_t FastCall(os_struct_func)(const os_func_args* args);

#endif /* __OS_API_H__ */
