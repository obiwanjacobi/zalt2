#pragma once
#include "avr/common.h"

// clang-format off

#ifndef ASM_VOLATILE
#define  ASM_VOLATILE(s)  __asm__ volatile (s)
#endif

class LockScope
{
public:
    LockScope()
    {
        Enter();
    }

    ~LockScope()
    {
        Exit();
    }

    void Enter()
    {
        _sreg = SREG;
        ASM_VOLATILE("cli" ::: "memory");
    }

    void Exit()
    {
        SREG = _sreg;
        ASM_VOLATILE("" ::: "memory");
    }

private:
    uint8_t _sreg;
};