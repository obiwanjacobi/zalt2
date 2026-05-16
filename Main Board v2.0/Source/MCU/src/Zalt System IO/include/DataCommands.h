#pragma once

#include "ProtocolTask.h"
#include <stdint.h>

enum class DataCommands : uint8_t
{
    None = 0,

    RtcDate = 0x01,
    RtcTime = 0x02,

    SettingRead = 0x03,
    SettingWrite = 0x04,
    SettingError = 0x05,

    FileOpenRead = 0x08,
    FileOpenWrite = 0x09,
    FileRead = 0x0A,
    FileWrite = 0x0B,
    FileClose = 0x0C,
    FileError = 0x0D,

    ConsoleRead0 = 0x10,
    ConsoleRead1 = 0x11,
    ConsoleWrite0 = 0x12,
    ConsoleWrite1 = 0x13,
    ConsoleError0 = 0x14,
    ConsoleError1 = 0x15,

    KeyboardRead = 0x18,
    KeyboardWrite = 0x19,

    TimerSet0 = 0x20,
    TimerSet1 = 0x21,
    TimerSet2 = 0x22,
    TimerSet3 = 0x23,
};

enum class StatusFlags : uint8_t
{
    None = 0,
    FileError = 0x01,
    Console0Error = 0x02,
    Console0OutputEmpty = 0x04,
    Console0InputFull = 0x08,
    Console1Error = 0x10,
    Console1OutputEmpty = 0x20,
    Console1InputFull = 0x40,
    Busy = 0x80,
};

class CommandHandler
{
public:
    virtual bool HandleCommand(DataCommands command) = 0;

    bool Run()
    {
        if (_current)
            return _current->Run();
        
        // signal end of function
        return true;
    }

protected:
    CommandHandler() : _current(nullptr) {}
    
    void setCurrentTask(ProtocolTask* task)
    {
        _current = task;
        if (_current)
            _current->ResetTask();
    }

private:
    ProtocolTask* _current;
};
