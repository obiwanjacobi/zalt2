#include "DataPort.h"
#include "LockScope.h"
#include "Port.h"

bool DataPort::CanWrite() const
{
    LockScope lock;
    return _writeBuffer.getCount() < _writeBuffer.getCapacity();
}
bool DataPort::TryWrite(uint8_t data)
{
    LockScope lock;
    return _writeBuffer.Write(data);
}
bool DataPort::CanRead() const
{
    LockScope lock;
    return !_readBuffer.getIsEmpty();
}
bool DataPort::TryRead(uint8_t* data)
{
    LockScope lock;
    return _readBuffer.TryRead(data);
}
void DataPort::setStatus(uint8_t status)
{
    LockScope lock;
    _status = status;
}
uint8_t DataPort::getCommand() const
{
    LockScope lock;
    return _command;
}

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
