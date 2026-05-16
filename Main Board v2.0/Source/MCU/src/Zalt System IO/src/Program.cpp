#include "DataPort.h"
#include "Program.h"
#include "Serial.h"

class Program
{
public:
    void Initialize()
    {
        // Start the timer that powers Time<TimeResolution> / Scheduler
        Scheduler::Start();

        // open console port (usart)
        if (!_userConsole.Open(BaudRates::Baud115200))
            Stop(1);

        // if (!_debugConsole.Open(BaudRates::Baud115200))
        //     Stop(2);
    }

    void Run()
    {
        if (_dataPort.hasNewCommand())
        {

        }
    }

    void Stop(uint8_t code)
    {
        if (code > 2)
        {
            _debugConsole.Transmit.Write("MCU Stopped with code: ");
            _debugConsole.Transmit.WriteLine(code);
        }
        else if (code > 1)
        {
            _userConsole.Transmit.Write("MCU Stopped with code: ");
            _userConsole.Transmit.WriteLine(code);
        }

        while (true);
    }

//private:
    UserConsole _userConsole;
    DebugConsole _debugConsole;
    DataPort _dataPort;
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
