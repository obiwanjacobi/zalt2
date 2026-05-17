#include "CommandHandler.h"
#include "DataCommands.h"
#include "DataPort.h"
#include "Serial.h"
#include "Task.h"

/// @brief Task for handling the ConsoleRead-n command. This is a multi-step task that will read the console input from the command buffer, process it, and then send a response back to the host.
class ConsoleReadTask : public ProtocolTask
{
public:
    ConsoleReadTask(DataPort& dataPort)
        : ProtocolTask(dataPort), _console(nullptr)
    {}

    Task_Begin(Run)
    {
        Task_WaitUntil(_console->TryRead(&_inputByte));
        Task_WaitUntil(SysDataPort.TryWrite(_inputByte));
    }
    Task_End;

    Console* _console;

private:
    uint8_t _inputByte;
};

/// @brief Task for handling the ConsoleWrite-n command. This is a multi-step task that will read the console input from the command buffer, process it, and then send a response back to the host.
class ConsoleWriteTask : public ProtocolTask
{
public:
    ConsoleWriteTask(DataPort& dataPort)
        : ProtocolTask(dataPort), _console(nullptr)
    {}

    Task_Begin(Run)
    {
        Task_WaitUntil(SysDataPort.TryRead(&_outputByte));
        Task_WaitUntil(_console->TryWrite(_outputByte));
    }
    Task_End;

    Console* _console;

private:
    uint8_t _outputByte;
};

class ConsoleCommandHandler : public CommandHandler
{
public:
    ConsoleCommandHandler(DataPort& dataPort, Console& console0, Console& console1) 
        : _consoleRead(dataPort), _consoleWrite(dataPort), 
        _console0(console0), _console1(console1)
    {}

    bool HandleCommand(DataCommands command)
    {
        switch (command)
        {
        case DataCommands::ConsoleRead0:
            _consoleRead._console = &_console0;
            setCurrentTask(&_consoleRead);
            break;
        case DataCommands::ConsoleRead1:
            _consoleRead._console = &_console1;
            setCurrentTask(&_consoleRead);
            break;
        case DataCommands::ConsoleWrite0:
            _consoleWrite._console = &_console0;
            setCurrentTask(&_consoleWrite);
            break;
        case DataCommands::ConsoleWrite1:
            _consoleWrite._console = &_console1;
            setCurrentTask(&_consoleWrite);
            break;
        default:
            setCurrentTask(nullptr);
            return false;
        }

        return true;
    }

    

private:
    ConsoleReadTask _consoleRead;
    ConsoleWriteTask _consoleWrite;
    Console& _console0;
    Console& _console1;
};
