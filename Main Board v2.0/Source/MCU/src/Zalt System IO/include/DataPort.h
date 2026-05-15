#pragma once

#include "DigitalInputPin.h"
#include "RingBuffer.h"

#include <stdint.h>

class DataPort
{
public:
    DataPort() = default;

    bool CanWrite() const { return _writeBuffer.getCount() < _writeBuffer.getCapacity(); }
    bool TryWrite(uint8_t data) { return _writeBuffer.Write(data); }
    bool CanRead() const { return !_readBuffer.getIsEmpty(); }
    bool TryRead(uint8_t* data) { return _readBuffer.TryRead(data); }

    void setStatus(uint8_t status) { _status = status; }
    bool hasNewCommand() const { return _command != _prevCommand; }
    uint8_t getCommand() const { return _command; }
    uint8_t getPrevCommand() const { return _prevCommand; }
    void setPrevCommand(uint8_t command) { _prevCommand = command; }

    void OnDataInterrupt();

private:
    DigitalInputPin<PortPins::B0> _dataDir;     // 0=wr/1=rd
    DigitalInputPin<PortPins::B1> _dataOrCmd;   // 0=data/1=cmd
    DigitalInputPin<PortPins::B2> _dataEnable;  // 0=disable/1=enable

    uint8_t _status;
    uint8_t _prevCommand;
    uint8_t _command;

    RingBuffer<uint8_t, 8> _readBuffer;
    RingBuffer<uint8_t, 8> _writeBuffer;
};
