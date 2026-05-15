#pragma once

#include "SpinWait.h"

#include <stdint.h>

/** The UsartOutputStream can be constructed around the UsartTransmist class
 *  to add buffered and interrupt based data transmission.
 *  \tparam BaseT is used as base class and is the UsartTransmit class and implements
 *  `void Flush()`
 *  `void setEnableWantDataInterrupt(bool)`
 *  `void Close()`
 *  `void WriteInternal(int16_t)` (protected)
 *  \tparam BufferT is class that implements the RingBuffer.
 *	`uint8/16_t getCount() const`
 *  `uint8/16_t getCapacity() const`
 *	`void Clear()`
 *	`int16_t Read()`
 *	`void Write(uint8/16_t)`
 */
template <typename BaseT, typename BufferT>
class UsartOutputStream : public BaseT
{
public:
    /** Returns the number of bytes in the stream.
     *  \return Returns 0 (zero) when empty.
     */
    uint8_t getCount() const
    {
        return _buffer.getCount();
    }

    bool getIsEmpty() const
    {
        return _buffer.getIsEmpty();
    }

    /** Removes all content from the output stream.
     */
    void Flush()
    {
        _buffer.Clear();
        BaseT::Flush();
    }

    bool getCanWrite() const
    {
        return getCount() < getBufferSize();
    }

    /** Writes one byte to the stream.
     *  \param data the byte that is written to the output stream.
     */
    void Write(uint8_t data)
    {
        // keep retrying till the buffer has space
        while (!_buffer.Write(data))
            SpinWait(1);
    }

    /** Call this method from the `ISR(USARTn_UDRE_vect)` interrupt handler.
     *  Not meant to be called from regular code.
     */
    void OnAcceptDataInterrupt()
    {
        if (_buffer.getCount() > 0)
        {
            // write the next byte from buffer
            BaseT::WriteInternal(_buffer.Read());
        }
    }

    /** Retrieves the buffer size used for storing transmit data.
     *  \return Returns the size of the internal buffer.
     */
    uint16_t getBufferSize() const
    {
        return _buffer.getCapacity();
    }

    /** Closes the output stream and transmitter.
     *  Data still in the buffer is lost.
     */
    void Close()
    {
        _buffer.Clear();
        BaseT::Close();
    }

private:
    BufferT _buffer;
};