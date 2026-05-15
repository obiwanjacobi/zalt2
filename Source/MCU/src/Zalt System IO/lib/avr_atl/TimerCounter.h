#pragma once
#include <avr/io.h>
#include <avr/interrupt.h>
#include "LockScope.h"
#include "TimeResolution.h"
#include "PowerReduction.h"

#ifdef TCNT0

// This class is a quick implementation taken from Arduino. Uses Timer0.
class TimerCounter0
{
// FROM ARDUINO
// Copyright (c) 2005-2006 David A. Mellis

// the prescaler is set so that timer0 ticks every 64 clock cycles, and the
// the overflow handler is called every 256 ticks.
#define Microseconds_Per_Timer0_Overflow ForClockCycles<TimeResolution::Microseconds>(64 * 256)

// the whole number of milliseconds per timer0 overflow
#define Timer0_Millis_Inc (Microseconds_Per_Timer0_Overflow / 1000)

// the fractional number of milliseconds per timer0 overflow. we shift right
// by three to fit these numbers into a byte. (for the clock speeds we care
// about - 8 and 16 MHz - this doesn't lose precision.)
#define Timer0_Fract_Inc ((Microseconds_Per_Timer0_Overflow % 1000) >> 3)
#define Timer0_Fract_Max (1000 >> 3)

public:
    static void Start()
    {
        PowerReduction::Timer0(PowerState::On);

        // set normal timer mode
        TCCR0A = 0;
        // clear counter register
        TCNT0 = 0;
        // prescaler to 64
        TCCR0B = (1 << CS00) | (1 << CS01);
        // clear any pending overflow interrupts
        TIFR0 = (1 << TOV0);
        // enable overflow interrupt
        TIMSK0 = (1 << TOIE0);
    }

    template <TimeResolution TimeResolution>
    static uint32_t getTime();

    static uint32_t getMilliseconds()
    {
        LockScope lock;
        return _milliCount;
    }

    static uint32_t getMicroseconds()
    {
        uint32_t micros;
        uint8_t count;

        {
            LockScope lock;

            micros = _overflowCount;
            count = TCNT0;

            if ((TIFR0 & (1 << TOV0)) && (count < 255))
                micros++;
        }

        return ((micros << 8) + count) * (64 / (F_CPU / 1000000L));
    }

    // Call from ISR(TIMER0_OVF_vect)
    static void OnTimerOverflowInterrupt()
    {
        // copy these to local variables so they can be stored in registers
        // (volatile variables must be read from memory on every access)
        uint32_t millis = _milliCount;
        uint32_t fract = _fractureCount;

        millis += Timer0_Millis_Inc;
        fract += Timer0_Fract_Inc;
        if (fract >= Timer0_Fract_Max)
        {
            fract -= Timer0_Fract_Max;
            millis += 1;
        }

        _milliCount = millis;
        _fractureCount = (uint8_t)fract;
        _overflowCount++;
    }

private:
    TimerCounter0() {}
    static volatile uint32_t _milliCount;
    static volatile uint32_t _overflowCount;
    static uint8_t _fractureCount; // not volatile, only accessed from within ISR
};

template <>
uint32_t TimerCounter0::getTime<TimeResolution::Microseconds>()
{
    return getMicroseconds();
}

template <>
uint32_t TimerCounter0::getTime<TimeResolution::Milliseconds>()
{
    return getMilliseconds();
}

volatile uint32_t TimerCounter0::_milliCount;
volatile uint32_t TimerCounter0::_overflowCount;
uint8_t TimerCounter0::_fractureCount;

// ISR(TIMER0_OVF_vect)
// {
//     TimerCounter0::OnTimerOverflowInterrupt();
// }

#endif // TCNT0

// ----------------------------------------------------------------------------

#ifdef TCNT1

// This class uses Timer1 (16-bit) for time tracking
class TimerCounter1
{
// Timer1 is 16-bit and we'll set it to overflow less frequently

// Set prescaler to 64, which makes timer1 tick every 64 clock cycles
// For a 16-bit timer, the overflow happens every 65536 ticks
#define Microseconds_Per_Timer1_Overflow ForClockCycles<TimeResolution::Microseconds>(64 * 65536)

// the whole number of milliseconds per timer1 overflow
#define Timer1_Millis_Inc (Microseconds_Per_Timer1_Overflow / 1000)

// the fractional number of milliseconds per timer1 overflow
#define Timer1_Fract_Inc (Microseconds_Per_Timer1_Overflow % 1000)
#define Timer1_Fract_Max (1000)

public:
    static void Start()
    {
        PowerReduction::Timer1(PowerState::On);

        // set normal timer mode
        TCCR1A = 0;
        // clear counter register
        TCNT1 = 0;
        // prescaler to 64
        TCCR1B = (1 << CS11) | (1 << CS10);
        // clear any pending overflow interrupts
        TIFR1 = (1 << TOV1);
        // enable overflow interrupt
        TIMSK1 = (1 << TOIE1);
    }

    template <TimeResolution TimeResolution>
    static uint32_t getTime();

    static uint32_t getMilliseconds()
    {
        LockScope lock;
        return _milliCount;
    }

    static uint32_t getMicroseconds()
    {
        uint32_t micros;
        uint16_t count;

        {
            LockScope lock;

            micros = _overflowCount;
            // TCNT1 is 16-bit so we need to read the high byte first
            count = TCNT1;

            if ((TIFR1 & (1 << TOV1)) && (count < 0xFFF0))
                micros++;
        }

        return ((micros << 16) + count) * (64 / (F_CPU / 1000000L));
    }

    // Call from ISR(TIMER1_OVF_vect)
    static void OnTimerOverflowInterrupt()
    {
        // copy these to local variables so they can be stored in registers
        uint32_t millis = _milliCount;
        uint32_t fract = _fractureCount;

        millis += Timer1_Millis_Inc;
        fract += Timer1_Fract_Inc;
        if (fract >= Timer1_Fract_Max)
        {
            fract -= Timer1_Fract_Max;
            millis += 1;
        }

        _milliCount = millis;
        _fractureCount = fract;
        _overflowCount++;
    }

private:
    TimerCounter1() {}
    static volatile uint32_t _milliCount;
    static volatile uint32_t _overflowCount;
    static uint16_t _fractureCount; // Note: increased to 16-bit for larger fraction values
};

template <>
uint32_t TimerCounter1::getTime<TimeResolution::Microseconds>()
{
    return getMicroseconds();
}

template <>
uint32_t TimerCounter1::getTime<TimeResolution::Milliseconds>()
{
    return getMilliseconds();
}

volatile uint32_t TimerCounter1::_milliCount;
volatile uint32_t TimerCounter1::_overflowCount;
uint16_t TimerCounter1::_fractureCount;

// ISR(TIMER1_OVF_vect)
// {
//     TimerCounter1::OnTimerOverflowInterrupt();
// }

#endif // TCNT1

// ----------------------------------------------------------------------------

#ifdef TCNT2

// This class implements timing functionality using Timer2.
class TimerCounter2
{
// The prescaler is set to 64, which makes timer2 ticks every 64 clock cycles, and the
// overflow handler is called every 256 ticks.
#define Microseconds_Per_Timer2_Overflow ForClockCycles<TimeResolution::Microseconds>(64 * 256)

// The whole number of milliseconds per timer2 overflow
#define Timer2_Millis_Inc (Microseconds_Per_Timer2_Overflow / 1000)

// The fractional number of milliseconds per timer2 overflow
#define Timer2_Fract_Inc ((Microseconds_Per_Timer2_Overflow % 1000) >> 3)
#define Timer2_Fract_Max (1000 >> 3)

public:
    static void Start()
    {
        PowerReduction::Timer2(PowerState::On);

        // Set normal timer mode
        TCCR2A = 0;
        // Clear counter register
        TCNT2 = 0;
        // Prescaler to 64
        TCCR2B = (1 << CS22);
        // Clear any pending overflow interrupts
        TIFR2 = (1 << TOV2);
        // Enable overflow interrupt
        TIMSK2 = (1 << TOIE2);
    }

    template <TimeResolution TimeResolution>
    static uint32_t getTime();

    static uint32_t getMilliseconds()
    {
        LockScope lock;
        return _milliCount;
    }

    static uint32_t getMicroseconds()
    {
        uint32_t micros;
        uint8_t count;

        {
            LockScope lock;

            micros = _overflowCount;
            count = TCNT2;

            if ((TIFR2 & (1 << TOV2)) && (count < 255))
                micros++;
        }

        return ((micros << 8) + count) * (64 / (F_CPU / 1000000L));
    }

    // Call from ISR(TIMER2_OVF_vect)
    static void OnTimerOverflowInterrupt()
    {
        // Copy these to local variables so they can be stored in registers
        // (volatile variables must be read from memory on every access)
        uint32_t millis = _milliCount;
        uint32_t fract = _fractureCount;

        millis += Timer2_Millis_Inc;
        fract += Timer2_Fract_Inc;
        if (fract >= Timer2_Fract_Max)
        {
            fract -= Timer2_Fract_Max;
            millis += 1;
        }

        _milliCount = millis;
        _fractureCount = (uint8_t)fract;
        _overflowCount++;
    }

private:
    TimerCounter2() {}
    static volatile uint32_t _milliCount;
    static volatile uint32_t _overflowCount;
    static uint8_t _fractureCount; // not volatile, only accessed from within ISR
};

template <>
uint32_t TimerCounter2::getTime<TimeResolution::Microseconds>()
{
    return getMicroseconds();
}

template <>
uint32_t TimerCounter2::getTime<TimeResolution::Milliseconds>()
{
    return getMilliseconds();
}

volatile uint32_t TimerCounter2::_milliCount;
volatile uint32_t TimerCounter2::_overflowCount;
uint8_t TimerCounter2::_fractureCount;

// ISR(TIMER2_OVF_vect)
// {
//     TimerCounter2::OnTimerOverflowInterrupt();
// }

#endif // TCNT2