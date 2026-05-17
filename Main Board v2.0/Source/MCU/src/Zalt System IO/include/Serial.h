#pragma once

#include "Usart.h"
#include "UsartInputStream.h"
#include "UsartOutputStream.h"
#include "RingBuffer.h"
#include "TextWriter.h"
#include "Slice.h"

enum class BaudRates : uint32_t
{
    Baud9600 = 9600,
    Baud19200 = 19200,
    Baud38400 = 38400,
    Baud57600 = 57600,
    Baud115200 = 115200
};

template <class BaseT>
class DataWriter : public BaseT
{
public:
    void WriteData(uint8_t data)
    {
        BaseT::Write(data);
    }
    void WriteBuffer(Slice<uint8_t> &buffer)
    {
        for (uint8_t i = 0; i < buffer.getLength(); i++)
        {
            BaseT::Write(buffer[i]);
        }
    }
};

const UsartIds ConsoleUsartId = UsartIds::Usart0;
const UsartIds DebugUsartId = UsartIds::Usart1;
const uint8_t CharacterBufferSize = 21;

template <const UsartIds usartId>
class SerialWriter : public TextWriter<DataWriter<UsartOutputStream<UsartTransmit<usartId>, RingBuffer<uint8_t, CharacterBufferSize>>>>
{};

template <const UsartIds usartId>
class SerialReader : public UsartInputStream<UsartReceive<usartId>, RingBuffer<uint8_t, CharacterBufferSize>>
{};

template <const UsartIds usartId>
class Serial : public Usart<usartId, SerialWriter<usartId>, SerialReader<usartId>>
{
    typedef Usart<usartId, SerialWriter<usartId>, SerialReader<usartId>> BaseT;
public:
    bool Open(BaudRates baudRate, bool enableInterrupts = true)
    {
        UsartConfig config;
        if (config.InitAsync((uint32_t)baudRate) &&
            BaseT::OpenAsync(config))
        {
            BaseT::Transmit.setEnable();
            BaseT::Transmit.setEnableAcceptDataInterrupt(enableInterrupts);
            BaseT::Receive.setEnable();
            BaseT::Receive.setEnableIsCompleteInterrupt(enableInterrupts);
            return true;
        }
        return false;
    }
};

// Provides a generic interface for templated implementaion.
class Console
{
public:
    virtual bool TryRead(uint8_t* outData) = 0;
    virtual bool TryWrite(uint8_t outData) = 0;
};

class UserConsole : public Serial<ConsoleUsartId>, public Console
{
    typedef Serial<ConsoleUsartId> BaseT;
public:
    bool TryRead(uint8_t* outData)
    {
        return BaseT::Receive.TryRead(outData);
    }
    bool TryWrite(uint8_t outData)
    {
        UsartTransmitResult result;
        if (BaseT::Transmit.TryWrite(outData, result))
        {
            return result == UsartTransmitResult::Success;
        }
        return false;
    }
};

class DebugConsole : public Serial<DebugUsartId>, public Console
{
    typedef Serial<DebugUsartId> BaseT;
public:
    bool TryRead(uint8_t* outData)
    {
        return BaseT::Receive.TryRead(outData);
    }
    bool TryWrite(uint8_t outData)
    {
        UsartTransmitResult result;
        if (BaseT::Transmit.TryWrite(outData, result))
        {
            return result == UsartTransmitResult::Success;
        }
        return false;
    }
};