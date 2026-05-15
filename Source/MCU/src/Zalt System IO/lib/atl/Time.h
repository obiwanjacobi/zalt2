#pragma once
#include <stdint.h>
#include <math.h>
#include <util/delay.h>
#include "TimeResolution.h"

// DEPENDENCIES!!
#include "../avr_atl/TimerCounter.h"
typedef TimerCounter0 TimerCounterT;

ISR(TIMER0_OVF_vect)
// ISR(TIMER1_OVF_vect)
// ISR(TIMER2_OVF_vect)
{
    TimerCounterT::OnTimerOverflowInterrupt();
}

/** The Time class keeps track of time ticks (either milli- or micro-seconds).
 *  Time is a static class and cannot be instantiated.
 *  \tparam TimeResolution indicates the units of time.
 */
template <const TimeResolution ResolutionId>
class Time
{
public:
    /** Starts the time counter.
     */
    static void Start() { TimerCounterT::Start(); }

    /** Captures the time ticks.
     *  \return Returns delta-time in 'resolution'
     */
    static uint32_t Update();

    /** Returns the time ticks in milli-seconds.
     */
    static uint32_t getMilliseconds()
    {
        return ::getMilliseconds<ResolutionId>(_ticks);
    }

    /** Returns the time ticks in micro-seconds.
     */
    static uint32_t getMicroseconds()
    {
        return ::getMicroseconds<ResolutionId>(_ticks);
    }

    /** Returns the raw time ticks.
     */
    static uint32_t getTicks()
    {
        return _ticks;
    }

    static uint32_t ForMilliseconds(uint32_t milliseconds)
    {
        return ::getMilliseconds<ResolutionId>(milliseconds);
    }

    static uint32_t ForMicroseconds(uint32_t microseconds)
    {
        return ::getMicroseconds<ResolutionId>(microseconds);
    }

    static TimeResolution getResolution()
    {
        return ResolutionId;
    }

    static void Wait(uint32_t delay);
    // blocks caller until delay has elapsed
    // delay in TimeResolution
    static void SpinWait(uint32_t delay);

private:
    Time() {}
    static uint32_t _ticks;
};

template <const TimeResolution ResolutionId>
uint32_t Time<ResolutionId>::_ticks = 0;

/** Captures the time ticks (specialized).
 *  \return Returns delta-time in microseconds.
 */
template <>
uint32_t Time<TimeResolution::Microseconds>::Update()
{
    uint32_t previous = _ticks;
    _ticks = TimerCounterT::getMicroseconds();
    return _ticks - previous;
}

/** Captures the time ticks (specialized).
 *  \return Returns delta-time in milliseconds.
 */
template <>
uint32_t Time<TimeResolution::Milliseconds>::Update()
{
    uint32_t previous = _ticks;
    _ticks = TimerCounterT::getMilliseconds();
    return _ticks - previous;
}

template <>
void Time<TimeResolution::Milliseconds>::SpinWait(uint32_t delay)
{
    uint32_t start = TimerCounterT::getMilliseconds();
    while (TimerCounterT::getMilliseconds() - start < delay)
        ;
}

template <>
void Time<TimeResolution::Microseconds>::SpinWait(uint32_t delay)
{
    uint32_t start = TimerCounterT::getMicroseconds();
    while (TimerCounterT::getMicroseconds() - start < delay)
        ;
}

template <>
void Time<TimeResolution::Milliseconds>::Wait(uint32_t delay)
{
    _delay_ms(delay);
}

template <>
void Time<TimeResolution::Microseconds>::Wait(uint32_t delay)
{
    _delay_us(delay);
}
