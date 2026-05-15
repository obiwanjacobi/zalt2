#pragma once
#include <stdint.h>

void SpinWait(uint16_t spinDelay)
{
    while (spinDelay-- > 0)
    {
        __asm__ __volatile__("nop");
    }
}
