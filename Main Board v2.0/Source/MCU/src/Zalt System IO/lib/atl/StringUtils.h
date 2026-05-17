#pragma once
#include "Collection.h"
#include "FixedString.h"
#include "TextWriter.h"
#include "TextFormatInfo.h"

// adapts stream interface to an array interface
template <typename BaseT>
class StringStream : public BaseT
{
public:
    // stream interface
    void Write(char character)
    {
        // array interface
        BaseT::Add(character);
    }
};

template <const uint8_t MaxSize>
class StringWriter : public TextWriter<StringStream<Collection<FixedString<MaxSize>>>>
{
public:
    operator const char* () const
    {
        return (const char *)this;
    }
};
