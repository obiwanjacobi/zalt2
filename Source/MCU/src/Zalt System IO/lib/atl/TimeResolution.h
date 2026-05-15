#pragma once
#include <stdint.h>

enum class TimeResolution
{
    /** Time units are milliseconds. */
    Milliseconds,
    /** Time units are microseconds. */
    Microseconds
};

template <TimeResolution ResolutionId>
uint32_t ForClockCycles(uint32_t clockCylces);

template <>
uint32_t ForClockCycles<TimeResolution::Milliseconds>(uint32_t clockCylces)
{
    return clockCylces / (F_CPU / 1000L);
}

template <>
uint32_t ForClockCycles<TimeResolution::Microseconds>(uint32_t clockCylces)
{
    return clockCylces / (F_CPU / 1000000L);
}

/** Returns the ticks in milli-seconds.
 */
template <TimeResolution ResolutionId>
uint32_t getMilliseconds(uint32_t ticks);

/** Specialization for Time in Milliseconds.
 */
template <>
uint32_t getMilliseconds<TimeResolution::Milliseconds>(uint32_t ticks)
{
    return ticks;
}

/** Specialization for Time in Microseconds.
 */
template <>
uint32_t getMilliseconds<TimeResolution::Microseconds>(uint32_t ticks)
{
    return ticks / 1000L;
}

/** Returns the ticks in micro-seconds.
 */
template <TimeResolution ResolutionId>
uint32_t getMicroseconds(uint32_t ticks);

/** Specialization for Time in Milliseconds.
 */
template <>
uint32_t getMicroseconds<TimeResolution::Milliseconds>(uint32_t ticks)
{
    return ticks * 1000L;
}

/** Specialization for Time in Microseconds.
 */
template <>
uint32_t getMicroseconds<TimeResolution::Microseconds>(uint32_t ticks)
{
    return ticks;
}

// for use in templates
#define ToMilliseconds(resolution, milliseconds) resolution == TimeResolution::Milliseconds ? milliseconds : ((uint32_t)milliseconds * 1000L)
#define ToMicroseconds(resolution, microseconds) resolution == TimeResolution::Milliseconds ? ((uint32_t)microseconds / 1000L) : microseconds
