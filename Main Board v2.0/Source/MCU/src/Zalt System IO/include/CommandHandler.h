#pragma once
#include "DataPort.h"

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
