#pragma once

/** The UsartInputStream can be constructed around the UsartReceive class
 *  to add buffered and interrupt based data reception.
 *  \tparam BaseT is used as base class and is the UsartReceive class and implements
 *  `void Clear()`
 *  `void setEnableIsCompleteInterrupt(bool)`
 *  `void Close()`
 *  `UsartReceiveResult getResult() const` (protected)
 *  `int16_t ReadInternal()` (protected)
 *  \tparam BufferT is class that implements the RingBuffer.
 *	`uint8/16_t getCount() const`
 *  `uint8/16_t getCapacity() const`
 *	`void Clear()`
 *	`int16_t Read()`
 *	`void Write(uint8/16_t)`
 */
template <typename BaseT, typename BufferT>
class UsartInputStream : public BaseT
{
public:
    /** Returns the number of bytes that are available in the stream.
     *  \return Returns 0 (zero) when empty.
     */
    uint16_t getCount() const
    {
        return _buffer.getCount();
    }

    bool getIsEmpty() const
    {
        return _buffer.getIsEmpty();
    }

    /** Removes all content from the stream.
     *  Keeps reading the input stream until there is nothing left.
     */
    void Clear()
    {
        BaseT::Clear();
        _buffer.Clear();
    }

    bool getCanRead() const
    {
        return !getIsEmpty() || BaseT::getCanRead();
    }

    /** Reads one byte from the stream.
     *  It turns on the receive interrupt when no data is available (first read is always -1).
     *  \return Returns the byte read in the lsb (up to 9 bits).
     *  If -1 is returned, no data was available or an error occurred.
     */
    int16_t Read()
    {
        if (!_buffer.getIsEmpty())
        {
            return _buffer.Read();
        }

        BaseT::setEnableIsCompleteInterrupt(true);
        return -1;
    }

    bool TryRead(uint8_t *outData)
    {
        if (!_buffer.getIsEmpty())
        {
            *outData = _buffer.Read();
            return true;
        }

        *outData = 0;
        BaseT::setEnableIsCompleteInterrupt(true);
        return false;
    }

    /** Call this method from the `ISR(USARTn_RX_vect)` interrupt handler.
     *  Not meant to be called from regular code.
     */
    void OnIsCompleteInterrupt()
    {
        UsartReceiveResult result = BaseT::getResult();
        int16_t data = BaseT::ReadInternal();

        if (result == UsartReceiveResult::Success)
            _buffer.Write((typename BufferT::ItemT)data);
    }

    /** Retrieves the buffer size used for storing received data.
     *  \return Returns the size of the internal buffer.
     */
    uint16_t getBufferSize() const
    {
        return _buffer.getCapacity();
    }

    /** Closes the input stream and receiver.
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