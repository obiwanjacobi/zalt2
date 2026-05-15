#pragma once
#include <stdint.h>
#include "LockScope.h"

/** A RingBuffer uses a fixed amount of memory to simulate an 'endless' buffer.
 *  Capacity is always one less than the specified Size.
 *  There is NO under-run detection!
 *  An Array of T[Size] is allocated.
 *  \tparam T is the data type of the buffer items.
 *  \tparam Size is the number of 'T' items in the buffer.
 */
template <typename T, const uint16_t Size>
class RingBuffer
{
    static_assert(Size > 1, "Size must be bigger than 1.");

public:
    typedef T ItemT;

    /** Constructs the instance.
     */
    RingBuffer()
        : _writeIndex(0), _readIndex(0)
    {
    }

    /** Clears the buffer.
     *  The actual content is not deleted or reset.
     */
    void Clear()
    {
        LockScope lock;

        _writeIndex = 0;
        _readIndex = 0;
    }

    /** Writes the value to the buffer.
     *  The method protects against overrun.
     *  \param value is the value to store in the buffer.
     *  \return Returns true when successful.
     */
    bool Write(T value)
    {
        LockScope lock;

        uint16_t newIndex = _writeIndex + 1;
        // check for overrun
        if (newIndex == _readIndex)
            return false;
        else if (newIndex >= Size && _readIndex == 0)
            return false;

        _buffer[_writeIndex] = value;
        _writeIndex = newIndex;

        if (_writeIndex >= Size)
            _writeIndex = 0;

        return true;
    }

    /** Reads one value from the buffer.
     *  The method does protect against under-run.
     *  \param outData is the value to store the read value.
     *  \return Returns true if the read was successfull and outData was filled.
     */
    bool TryRead(T *outData)
    {
        // empty
        if (_readIndex == _writeIndex)
        {
            outData = nullptr;
            return false;
        }

        *outData = _buffer[_readIndex];
        _readIndex++;

        if (_readIndex >= Size)
            _readIndex = 0;

        return true;
    }

    /** Reads one value from the buffer.
     *  The method does NOT protect against underrun.
     *  \return Returns the value.
     */
    T Read()
    {
        LockScope lock;

        T result = _buffer[_readIndex];
        _readIndex++;

        if (_readIndex >= Size)
            _readIndex = 0;

        return result;
    }

    /** Retrieves the number of values in the buffer.
     *  \return Returns the length of the buffer.
     */
    uint16_t getCount() const
    {
        LockScope lock;

        if (_writeIndex >= _readIndex)
        {
            return _writeIndex - _readIndex;
        }

        return getCapacity() - (_readIndex - _writeIndex);
    }

    bool getIsEmpty() const
    {
        return _writeIndex == _readIndex;
    }

    uint16_t getCapacity() const
    {
        return Size - 1;
    }

private:
    volatile T _buffer[Size];
    volatile uint16_t _writeIndex;
    volatile uint16_t _readIndex;
};

//-----------------------------------------------------------------------------

/** A smaller (max 254 items) and faster RingBuffer.
 *	Because of its reduced size no atomic access to its buffer is required. (sizeof(T) == 8!)
 *  Capacity is always one less than the specified Size.
 *  There is NO under-run detection! Call `getCount()` or `getIsEmpty()` before calling `Read()`.
 *  An Array of T[Size+1] is allocated.
 *  \tparam T is the data type of the buffer items.
 *  \tparam Size is the number of 'T' items in the buffer.
 */
template <typename T, const uint8_t Size>
class RingBufferFast
{
    static_assert(Size > 1, "Size must be bigger than 1.");
    static_assert(Size < 255, "Size must be less than 255!");
#define ActualSize (Size + 1)

public:
    typedef T ItemT;

    /** Constructs the instance.
     */
    RingBufferFast()
        : _writeIndex(0), _readIndex(0)
    {
    }

    /** Clears the buffer.
     *  The actual content is not deleted or reset.
     */
    void Clear()
    {
        _writeIndex = 0;
        _readIndex = 0;
    }

    /** Writes the value to the buffer.
     *  The method protects against overrun.
     *  \param value is the value to store in the buffer.
     *  \return Returns true when successful.
     */
    bool Write(T value)
    {
        uint8_t newIndex = _writeIndex + 1;
        if (newIndex >= ActualSize)
        {
            // wrap around
            newIndex = 0;
        }

        // collision detection (buffer full condition)
        if (newIndex == _readIndex)
            return false;

        _buffer[_writeIndex] = value;
        _writeIndex = newIndex;
        return true;
    }

    /** Retrieves an indication if a call to `Write()` will succeed.
     *  \return Returns true if `Write()` can be called.
     */
    bool getCanWrite() const
    {
        return getCapacity() - getCount() > 0;
    }

    /** Reads one value from the buffer.
     *  The method does NOT protect against under-run. Call `getCount()`.
     *  \return Returns the value.
     */
    T Read()
    {
        T result = _buffer[_readIndex];
        _readIndex++;

        if (_readIndex >= ActualSize)
        {
            _readIndex = 0;
        }

        return result;
    }

    /** Reads one value from the buffer.
     *  The method does protect against under-run.
     *  \param outData is the value to store the read value.
     *  \return Returns true if the read was successfull and outData was filled.
     */
    bool TryRead(T *outData)
    {
        if (getCount() == 0)
        {
            outData = nullptr;
            return false;
        }

        *outData = _buffer[_readIndex];
        _readIndex++;

        if (_readIndex >= ActualSize)
        {
            _readIndex = 0;
        }

        return true;
    }

    /**
     * Reads multiple values from the buffer.
     * The method does protect against under-run.
     */
    uint16_t Read(T *outData, uint16_t maxCount)
    {
        T *p = outData;
        uint16_t count = 0;

        while (TryRead(p++) && count < maxCount)
        {
            count++;
        }

        return count;
    }

    /** Retrieves the number of values in the buffer.
     *  \return Returns the length of the buffer.
     */
    uint8_t getCount() const
    {
        if (_writeIndex >= _readIndex)
        {
            return _writeIndex - _readIndex;
        }

        return ActualSize - (_readIndex - _writeIndex);
    }

    bool getIsEmpty() const
    {
        return _writeIndex == _readIndex;
    }

    uint8_t getCapacity() const
    {
        return Size;
    }

private:
    volatile T _buffer[ActualSize];
    volatile uint8_t _writeIndex;
    volatile uint8_t _readIndex;
};