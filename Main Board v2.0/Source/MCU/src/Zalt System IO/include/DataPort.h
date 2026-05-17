#pragma once

#include "DigitalInputPin.h"
#include "RingBuffer.h"
#include "DataCommands.h"

#include <stdint.h>

class DataPort
{
public:
    DataPort() = default;

    bool CanWrite() const;
    bool TryWrite(uint8_t data);
    bool CanRead() const;
    bool TryRead(uint8_t* data);

    void setStatus(StatusFlags status);
    DataCommands getCommand() const;

    void OnDataInterrupt();

private:
    DigitalInputPin<PortPins::B0> _dataDir;     // 0=wr/1=rd
    DigitalInputPin<PortPins::B1> _dataOrCmd;   // 0=data/1=cmd
    DigitalInputPin<PortPins::B2> _dataEnable;  // 0=disable/1=enable

    StatusFlags _status;
    DataCommands _command;

    RingBuffer<uint8_t, 8> _readBuffer;
    RingBuffer<uint8_t, 8> _writeBuffer;
};

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
