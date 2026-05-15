#pragma once
#include <stdint.h>

template <typename T>
class Slice
{
public:
    Slice(T *value, uint8_t length)
        : _value(value), _length(length)
    {
    }

    Slice(Slice<T> &slice, uint8_t length)
        : _value(slice._value), _length(length)
    {
        if (slice._length < length)
            _length = slice._length;
    }

    T &operator[](uint8_t index)
    {
        if (!IsValidIndex(index))
            return _value[_length - 1];

        return _value[index];
    }

    const T &operator[](uint8_t index) const
    {
        if (!IsValidIndex(index))
            return _value[_length - 1];

        return _value[index];
    }

    const T *getValue() const
    {
        return _value;
    }
    uint8_t getLength() const
    {
        return _length;
    }

    bool IsValidIndex(uint8_t index) const
    {
        return index < _length;
    }

private:
    T *_value;
    uint8_t _length;
};
