#pragma once
#include <stdint.h>
#include "Task.h"

/** The TimeoutTask counts a timer down asynchronously (non-blocking).
 *  Calls the BaseT::OnTimeout when the Timeout has expired.
 *  Call the Execute method repeatedly.
 *  \tparam BaseT is used as a base class and implements:
 *  `void OnTimeout()`
 *  `uint16_t getId()` (IdentifiableObject).
 *  \tparam DelaysT is a Delays<> type used to keep track of timeouts.
 *  \tparam Timeout is specified in the same quantity as the DelaysT is specified (Milli- or MicroSeconds).
 */
template <class BaseT, typename DelaysT, const uint32_t Timeout>
class TimeoutTask : public BaseT
{
public:
    /** Constructs the instance.
     */
    TimeoutTask()
        : _task(0)
    {
    }

    /** Call this method repeatedly from the main loop.
     *  Each time the Timeout expires the BaseT::OnTimeout() method is called.
     */
    Task_Begin(Run)
    {
        Task_WaitUntil(DelaysT::Delay(BaseT::getId(), Timeout));
        BaseT::OnTimeout();
    }
    Task_End;

    /** Returns the Timeout template parameter.
     */
    uint32_t
    getTimeout() const
    {
        return Timeout;
    }

private:
    uint16_t _task; // required by the Task macros
};