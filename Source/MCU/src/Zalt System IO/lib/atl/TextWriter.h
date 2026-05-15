#pragma once
#include <stdint.h>
#include "TextFormatInfo.h"

/** The TextWriter class writes textual representations to a
 *  \tparam BaseT is derived from and implements 'void Write(byte)'.
 *  \tparam FormatInfoT implements all the public static fields defined by TextFormatInfo
 */
template <class BaseT, class FormatInfoT = TextFormatInfo>
class TextWriter : public BaseT
{
public:
    /** Writes the char value to the out stream as is.
     *  \param value is the character to write.
     */
    void Write(const char value)
    {
        BaseT::Write(value);
    }

    /** Writes a textual representation for the value.
     *  \param value is the number to convert to string.
     *  \param fixedLength is the number of total characters to display (leading zeros).
     */
    void Write(const uint8_t value, const uint8_t fixedLength = 0)
    {
        Write((uint16_t)value, fixedLength);
    }

    /** Writes a string to the out stream as is.
     *  Does NOT write the terminating zero!
     *  \param str points to the string to write.
     */
    void Write(const char str[])
    {
        const char *strPos = str;

        while (*strPos != '\0')
        {
            BaseT::Write(*strPos);
            strPos++;
        }
    }

    /** Writes a textual representation for the value.
     *  \param value is the number to convert to string.
     *  \param fixedLength is the number of total characters to display (leading zeros).
     */
    void Write(const int16_t value, const uint8_t fixedLength = 0)
    {
        // test for negative with decimals
        if (FormatInfoT::DefaultBase == TextFormatInfo::baseDecimal)
        {
            if (value < 0)
            {
                BaseT::Write(FormatInfoT::NegativeSign);
                WriteInt(-value, FormatInfoT::DefaultBase, fixedLength);
            }
            else
            {
                WriteInt(value, FormatInfoT::DefaultBase, fixedLength);
            }
        }
        else
        {
            return WriteInt(value, FormatInfoT::DefaultBase, fixedLength);
        }
    }

    /** Writes a textual representation for the value.
     *  \param value is the number to convert to string.
     *  \param fixedLength is the number of total characters to display (leading zeros).
     */
    void Write(const uint16_t value, const uint8_t fixedLength = 0)
    {
        WriteInt(value, FormatInfoT::DefaultBase, fixedLength);
    }

    /** Writes a textual representation for the value.
     *  \param value is the number to convert to string.
     */
    void Write(const int32_t value, const uint8_t fixedLength = 0)
    {
        // test for negative with decimals
        if (FormatInfoT::DefaultBase == TextFormatInfo::baseDecimal)
        {
            if (value < 0)
            {
                BaseT::Write(FormatInfoT::NegativeSign);
                WriteLong(-value, FormatInfoT::DefaultBase, fixedLength);
            }
            else
            {
                WriteLong(value, FormatInfoT::DefaultBase, fixedLength);
            }
        }
        else
        {
            return WriteLong(value, FormatInfoT::DefaultBase, fixedLength);
        }
    }

    /** Writes a textual representation for the value.
     *  \param value is the number to convert to string.
     *  \param fixedLength is the number of total characters to display (leading zeros).
     */
    void Write(const uint32_t value, const uint8_t fixedLength = 0)
    {
        WriteLong(value, FormatInfoT::DefaultBase, fixedLength);
    }

    /** Writes a textual representation for the value.
     *  \param value is the number to convert to string.
     */
    void Write(const float value)
    {
        WriteReal(value, FormatInfoT::DecimalDigits);
    }

    /** Writes a textual representation for the value.
     *  \param value is the number to convert to string.
     */
    void Write(const double value)
    {
        WriteReal(value, FormatInfoT::DecimalDigits);
    }

    /** Writes a the NewLine characters to the out stream.
     */
    void WriteLine()
    {
        Write(FormatInfoT::NewLine);
    }

    /** Writes the char value to the out stream as is followed by a NewLine.
     *  \param value is the character to write.
     */
    void WriteLine(const char value)
    {
        Write(value);
        WriteLine();
    }

    /** Writes a textual representation for the value followed by a NewLine.
     *  \param value is the number to convert to string.
     */
    void WriteLine(const uint8_t value)
    {
        Write(value);
        WriteLine();
    }

    /** Writes a string to the out stream as is followed by a NewLine.
     *  Does NOT write the terminating zero!
     *  \param str points to the string to write.
     */
    void WriteLine(const char str[])
    {
        Write(str);
        WriteLine();
    }

    /** Writes a textual representation for the value followed by a NewLine.
     *  \param value is the number to convert to string.
     */
    void WriteLine(const int16_t value)
    {
        Write(value);
        WriteLine();
    }

    /** Writes a textual representation for the value followed by a NewLine.
     *  \param value is the number to convert to string.
     */
    void WriteLine(const uint16_t value)
    {
        Write(value);
        WriteLine();
    }

    /** Writes a textual representation for the value followed by a NewLine.
     *  \param value is the number to convert to string.
     */
    void WriteLine(const int32_t value)
    {
        Write(value);
        WriteLine();
    }

    /** Writes a textual representation for the value followed by a NewLine.
     *  \param value is the number to convert to string.
     */
    void WriteLine(const uint32_t value)
    {
        Write(value);
        WriteLine();
    }

    /** Writes a textual representation for the value followed by a NewLine.
     *  \param value is the number to convert to string.
     */
    void WriteLine(const float value)
    {
        Write(value);
        WriteLine();
    }

    void WriteInt(uint16_t integer, uint8_t base, const uint8_t fixedLength = 0)
    {
        // an int is 2^32 and has 10 digits + terminating 0
        WriteInternal<unsigned int, 11>(integer, base, fixedLength);
    }

    void WriteLong(uint32_t integer, uint8_t base, const uint8_t fixedLength = 0)
    {
        // a long is 2^64 and has 20 digits + terminating 0
        WriteInternal<uint32_t, 21>(integer, base, fixedLength);
    }

private:
    template <typename T, const uint8_t bufferSize>
    void WriteInternal(T integer, uint8_t base, const uint8_t fixedLength)
    {
        char buffer[bufferSize];
        char *strPos = &buffer[bufferSize - 1];
        char *strEnd = strPos;

        // we fill the buffer from back to front.
        *strPos = '\0';

        // safety check for base values that crash
        // base == 0 -> divide by zero
        // base == 1 -> endless loop
        if (base < 2)
            base = 10;

        do
        {
            T remainder = integer;
            integer /= base;

            char c = (char)(remainder - base * integer);
            *--strPos = c < 10 ? c + '0' : c + 'A' - 10;
        } while (integer != 0);

        // leading zeros
        while (fixedLength - (strEnd - strPos) > 0 && strPos > buffer)
            *--strPos = '0';

        Write(strPos);
    }

    void WriteReal(double real, uint8_t digits)
    {
        if (real < 0.0)
        {
            BaseT::Write(FormatInfoT::NegativeSign);
            real = -real;
        }

        double rounding = 0.5;

        if (digits > 0)
        {
            for (int n = 0; n < digits; n++)
            {
                rounding /= 10.0;
            }
        }

        real += rounding;

        // integral part
        uint32_t integer = (uint32_t)real;
        double remainder = real - (double)integer;
        WriteLong(integer, TextFormatInfo::baseDecimal);

        if (digits > 0)
        {
            // decimal point
            BaseT::Write(FormatInfoT::DecimalSeparator);

            // decimals
            while (digits > 0)
            {
                remainder *= 10.0;
                uint16_t number = (unsigned int)remainder;
                WriteInt(number, TextFormatInfo::baseDecimal);
                remainder -= number;

                digits--;
            }
        }
    }
};
