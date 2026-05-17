// comment out to disable debug output
#define DEBUG
#include "Debug.h"

#include "DataPort.h"
#include "Program.h"
#include "Serial.h"
#include "StringUtils.h"

#include "RtcCommandHandler.cpp"
#include "ConsoleCommandHandler.cpp"

class Program
{
public:
    static const uint8_t ProgramComponentId = 0x10;

    Program()
        : _prevCommand(DataCommands::None), _currentCommandHandler(nullptr),
          _rtcCommandHandler(_dataPort), _consoleCommandHandler(_dataPort, _userConsole, _debugConsole)
          
    {}

    void Initialize()
    {
        // Start the timer that powers Time<TimeResolution> / Scheduler
        Scheduler::Start();

        // open console port (usart)
        if (!_userConsole.Open(BaudRates::Baud115200))
            Stop(1);

        if (!_debugConsole.Open(BaudRates::Baud115200))
            Stop(2);
    }

    void Run()
    {
        DataCommands command = _dataPort.getCommand();
        if (_prevCommand != command)
        {
            _currentCommandHandler = nullptr;
            _prevCommand = command;
            Information("Received command: ", (uint8_t)command);

            if (_rtcCommandHandler.HandleCommand(command))
            {
                _currentCommandHandler = &_rtcCommandHandler;
            }
            else if (_consoleCommandHandler.HandleCommand(command))
            {
                _currentCommandHandler = &_consoleCommandHandler;
            }
            else
            {
                Warning("Unhandled command: ", (uint8_t)command);
            }
        }

        if (_currentCommandHandler)
        {
            if (_currentCommandHandler->Run())
            {
                Information("Completed command: ", (uint8_t)command);
                _currentCommandHandler = nullptr;
            }
        }
    }

    void Stop(uint8_t code)
    {
        // Don't use Debug-logging, for it can be turned off.

        if (code > 2)
        {
            _debugConsole.Transmit.WriteLine("CRITICAL: MCU stopped:" + code);
        }
        else if (code > 1)
        {
            _userConsole.Transmit.WriteLine("CRITICAL: Failed to open debug console.");
        }
        else
        {
            // TODO: blink the SPI-SS pin as a last resort
        }

        while (true);
    }

//private:
    UserConsole _userConsole;
    DebugConsole _debugConsole;
    DataPort _dataPort;

private:
    DataCommands _prevCommand;
    CommandHandler* _currentCommandHandler;
    RtcCommandHandler _rtcCommandHandler;
    ConsoleCommandHandler _consoleCommandHandler;

    template <typename T>
    void Information(const char* message, T value)
    {
        if (Debug<ProgramComponentId>::CanLog<DebugLevel::Info>())
        {
            StringWriter<42> str;
            str.Write(message);
            str.Write(value);
            LogInfo<ProgramComponentId>(str);
        }
    }

    template <typename T>
    void Warning(const char* message, T value)
    {
        if (Debug<ProgramComponentId>::CanLog<DebugLevel::Warning>())
        {
            StringWriter<42> str;
            str.Write(message);
            str.Write(value);
            LogWarning<ProgramComponentId>(str);
        }
    }
};

Program program;

int main()
{
    program.Initialize();

    while (true) {
        program.Run();
    }

    return 0;
}

// user console
ISR(USART0_RX_vect)
{
    program._userConsole.Receive.OnIsCompleteInterrupt();
}

ISR(USART0_UDRE_vect)
{
    program._userConsole.Transmit.OnAcceptDataInterrupt();
}

// debug console
ISR(USART1_RX_vect)
{
    program._debugConsole.Receive.OnIsCompleteInterrupt();
}

ISR(USART1_UDRE_vect)
{
    program._debugConsole.Transmit.OnAcceptDataInterrupt();
}

// data exchange is triggered by an external interrupt on pin B2 (INT2)
ISR(INT2_vect)
{
    program._dataPort.OnDataInterrupt();
}

#ifdef DEBUG

void AtlDebugWrite(uint8_t componentId, DebugLevel level, const char *message)
{
    // switch (level)
    // {
    // case DebugLevel::Critical:
    //     serial.Transmit.Write("!!:");
    //     break;
    // case DebugLevel::Error:
    //     serial.Transmit.Write("!:");
    //     break;
    // case DebugLevel::Warning:
    //     serial.Transmit.Write("?:");
    //     break;
    // case DebugLevel::Info:
    //     serial.Transmit.Write("i:");
    //     break;
    // case DebugLevel::Trace:
    //     serial.Transmit.Write("t:");
    //     break;
    // case DebugLevel::Debug:
    //     serial.Transmit.Write("d:");
    //     break;
    // default:
    //     break;
    // }

    // TODO: {ticks}
    // TODO: [componentId] (lookup?)

    program._debugConsole.Transmit.WriteLine(message);
}

// void AtlDebugWrite(uint8_t componentId, DebugLevel level, const char *message)
// {
//     serial.Transmit.Write(Scheduler::getTicks());
//     serial.Transmit.Write(" [");
//     serial.Transmit.Write(componentId);
//     serial.Transmit.Write("] ");

//     switch (level)
//     {
//     case DebugLevel::Critical:
//         serial.Transmit.Write("CRITICAL: ");
//         break;
//     case DebugLevel::Error:
//         serial.Transmit.Write("ERROR: ");
//         break;
//     case DebugLevel::Warning:
//         serial.Transmit.Write("WARNING: ");
//         break;
//     case DebugLevel::Info:
//         serial.Transmit.Write("INFO: ");
//         break;
//     case DebugLevel::Trace:
//         serial.Transmit.Write("TRACE: ");
//         break;
//     case DebugLevel::Debug:
//         serial.Transmit.Write("DEBUG: ");
//         break;
//     default:
//         break;
//     }
//     serial.Transmit.WriteLine(message);
// }

bool AtlDebugFilter(uint8_t componentId, DebugLevel level)
{
    // if (level > DebugLevel::Warning)
    //     return false;

    // if (componentId == 1)
    //     return false;

    return true;
}

#endif // DEBUG
