#pragma once
#include <avr\pgmspace.h>

template <typename T, const uint8_t TypeSize = sizeof(T)>
class ProgMemAccessor
{
public:
    inline static T Read(const void *address);
};

// Specializations based on type size

template <typename T>
class ProgMemAccessor<T, 1>
{
public:
    inline static T Read(const void *address)
    {
        return (T)pgm_read_byte_near(address);
    }
};

template <typename T>
class ProgMemAccessor<T, 2>
{
public:
    inline static T Read(const void *address)
    {
        return (T)pgm_read_word_near(address);
    }
};

template <typename T>
class ProgMemAccessor<T, 4>
{
public:
    inline static T Read(const void *address)
    {
        return (T)pgm_read_dword_near(address);
    }
};

template <>
class ProgMemAccessor<float, 4>
{
public:
    inline static float Read(const void *address)
    {
        return (float)pgm_read_float_near(address);
    }
};