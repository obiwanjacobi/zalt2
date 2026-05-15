#include "DataPort.h"
#include "Port.h"

void DataPort::OnDataInterrupt()
{
    if (!_dataEnable.Read()) // active low
    {
        if (_dataDir.Read()) // 0=write/1=read
        {
            // CPU wants to read, we write
            uint8_t data;
            if (_writeBuffer.TryRead(&data))
            {
                if (_dataOrCmd.Read()) // 0=data/1=cmd
                    Port<Ports::A>::WriteAll(_status);
                else
                    Port<Ports::A>::WriteAll(data);

                Port<Ports::A>::SetDirection(0x00); // set all pins to input
            }
        }
        else
        {
            // CPU wants to write, we read
            uint8_t data = Port<Ports::A>::ReadAll();

            if (_dataOrCmd.Read())  // 0=data/1=cmd
            {
                _command = data;
                _readBuffer.Clear();
                _writeBuffer.Clear();
            }
            else
                _readBuffer.Write(data);
        }
    }
}
