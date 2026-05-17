#include "CommandHandler.h"
#include "DataCommands.h"
#include "DataPort.h"
#include "Task.h"

/// @brief Task for handling the RtcDate command. This is a multi-step task that will read the date from the command buffer, set the RTC date, and then send a response back to the host.
class RtcDateTask : public ProtocolTask
{
public:
    RtcDateTask(DataPort& dataPort)
        : ProtocolTask(dataPort)
    {}

    Task_Begin(Run)
    {
        // TODO: get Date from Rtc

        Task_WaitUntil(SysDataPort.TryWrite(year));
        Task_WaitUntil(SysDataPort.TryWrite(month));
        Task_WaitUntil(SysDataPort.TryWrite(day));
    }
    Task_End;

private:
    uint8_t year = 0;
    uint8_t month = 0;
    uint8_t day = 0;
};

/// @brief Task for handling the RtcTime command. This is a multi-step task that will read the time from the command buffer, set the RTC time, and then send a response back to the host.
class RtcTimeTask : public ProtocolTask
{
public:
    RtcTimeTask(DataPort& dataPort)
        : ProtocolTask(dataPort)
    {}

    Task_Begin(Run)
    {
        // TODO: get Time from Rtc
        
        Task_WaitUntil(SysDataPort.TryWrite(hour));
        Task_WaitUntil(SysDataPort.TryWrite(minute));
        Task_WaitUntil(SysDataPort.TryWrite(second));
    }
    Task_End;

private:
    uint8_t hour = 0;
    uint8_t minute = 0;
    uint8_t second = 0;
};

class RtcCommandHandler : public CommandHandler
{
public:
    RtcCommandHandler(DataPort& dataPort) 
        : _rtcDate(dataPort), _rtcTime(dataPort)
    {}

    bool HandleCommand(DataCommands command)
    {
        switch (command)
        {
        case DataCommands::RtcDate:
            setCurrentTask(&_rtcDate);
            break;
        case DataCommands::RtcTime:
            setCurrentTask(&_rtcTime);
            break;
        default:
            setCurrentTask(nullptr);
            return false;
        }

        return true;
    }

private:
    RtcDateTask _rtcDate;
    RtcTimeTask _rtcTime;
};
