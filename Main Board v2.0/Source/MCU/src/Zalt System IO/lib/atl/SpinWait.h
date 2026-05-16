#pragma once
#include <stdint.h>

template <typename T>
void SpinWait(T spinDelay)
{
    while (spinDelay-- > 0)
    {
        __asm__ __volatile__("nop");
    }
}
