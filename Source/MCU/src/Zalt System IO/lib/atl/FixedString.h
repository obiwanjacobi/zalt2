#pragma once
#include <stdint.h>
#include <string.h>
#include <avr/pgmspace.h>
#include "FixedArray.h"

/** FixedString is a specialized FixedArray for character strings.
 *  \tparam MaxChars indicates the maximum number of characters in the string.
 *  The underlying array has one extra byte for the terminating zero.
 *  \tparam FillChar the character used for filling out the capacity.
 *  Default is 0 which is no filling.
 */
template <const uint8_t MaxChars, const char FillChar = 0>
class FixedString : public FixedArray<char, MaxChars + 1>
{
    typedef FixedArray<char, MaxChars + 1> BaseT;

public:
    /** ItemT defines the type of array items.
     */
    typedef char ItemT;

    /** Constructs a blank instance.
     */
    FixedString()
    {
        BaseT::Clear();
        CopyFrom(nullptr);
    }

    /** Constructs an initialized instance.
     *  \param text points to a zero-terminated string used to initialize (copy) this instance.
     */
    FixedString(const char *text)
    {
        BaseT::Clear();
        CopyFrom(text);
    }

    /** Gets the maximum number of chars the string can store.
     *  \return Returns the MaxChars template parameter.
     */
    uint16_t getCapacity() const
    {
        return MaxChars;
    }

    /** Gets the current number of chars in the string.
     *  \return Returns the string length.
     */
    uint16_t getCount() const
    {
        return strlen((const char *)this);
    }

    /** Copy's in the specified text.
     *  Will never copy more than MaxChars characters from text.
     *  \param text is a pointer to a zero-terminated string.
     *      If null the entire string filled with `FillChar`.
     */
    void CopyFrom(const char *text)
    {
        size_t len = 0;
        auto buffer = BaseT::getBuffer();
        const uint16_t maxChars = BaseT::getCapacity();

        if (text != nullptr)
        {
            len = strlen(text);
            strncpy(buffer, text, maxChars);
        }

        if (len < maxChars)
            memset(buffer + len, FillChar, maxChars - len);

        buffer[maxChars - 1] = 0;
    }

    /** Copy's in the specified text from PROGMEM.
     *  Will never copy more than MaxChars characters from text.
     *  \param text is a pointer to a zero-terminated string in PROGMEM.
     */
    void CopyFromProgMem(const char *text)
    {
        auto len = strlen_P(text);
        auto buffer = BaseT::getBuffer();
        const uint16_t maxChars = BaseT::getCapacity();

        strncpy_P(buffer, text, maxChars);

        if (len < maxChars)
            memset(buffer + len, FillChar, maxChars - len);

        buffer[maxChars - 1] = 0;
    }

    /** Copy's in the specified text.
     *  Will never copy more than MaxChars characters from text.
     *  \param text is a pointer to a zero-terminated string.
     */
    void operator=(const char *text)
    {
        CopyFrom(text);
    }
};