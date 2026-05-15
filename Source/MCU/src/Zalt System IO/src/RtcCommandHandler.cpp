#include "DataCommands.h"
#include "Task.h"

class RtcCommandHandler
{
public:
    bool CanHandleCommand(uint8_t command) const
    {
        switch ((DataCommands)command)
        {
        case DataCommands::RtcDate:
        case DataCommands::RtcTime:
            return true;
        default:
            return false;
        }
    }

    void HandleCommand(uint8_t command)
    {
        switch ((DataCommands)command)
        {
        case DataCommands::RtcDate:
            _current = &_rtcDateProgress;
            break;
        case DataCommands::RtcTime:
            //_current = &_rtcTimeProgress;
            break;
        default:
            _current = nullptr;
            break;
        }
    }

    bool Run()
    {
        if (_current)
            return _current->Run();
        
        // signal end of function
        return true;
    }

private:
    Progress* _current;
    RtcDateProgress _rtcDateProgress;
    //RtcTimeProgress _rtcTimeProgress;
};

class Progress
{
public:
    virtual bool Run() = 0;
    virtual void Reset() { _task = 0; };

protected:
    uint16_t _task;
};

class RtcDateProgress : public Progress
{
public:

    Task_Begin(Run)
    {

    }
    Task_End;

};