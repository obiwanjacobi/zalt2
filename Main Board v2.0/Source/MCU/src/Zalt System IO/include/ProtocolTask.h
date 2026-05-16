#pragma once
#include "DataPort.h"
#include "Task.h"
#include <stdint.h>

class ProtocolTask
{
public:
    // Task_Begin(Run) {...} Task_End;
    /// @brief Runs the task. Returns true if the task is complete, false if it needs to be called again.
    virtual bool Run() = 0;
    
    /// @brief Resets the task to its starting-state.
    void ResetTask() { _task = 0; };

protected:
    ProtocolTask(DataPort& dataPort)
        : SysDataPort(dataPort), _task(0)
    {}

    DataPort& SysDataPort;
    uint16_t _task;
};
