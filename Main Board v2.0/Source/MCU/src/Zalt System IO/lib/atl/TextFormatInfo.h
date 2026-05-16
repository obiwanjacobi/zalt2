#pragma once
#include <stdint.h>

/** This class defines regional number-settings.
 *  See also TextWriter.
 */
class TextFormatInfo
{
public:
    /** Common bases for displaying decimal numbers as text.
     *
     */
    enum BaseTypes
    {
        /** Not set. */
        baseNone = 0,
        /** Binary (2). */
        baseBinary = 2,
        /** Octal (8). */
        baseOctal = 8,
        /** Decimal (10). */
        baseDecimal = 10,
        /** Hexadecimal (16). */
        baseHexadecimal = 16,
    };

    /** The characters that constitute a new-line. Ends with a terminating zero. */
    static char NewLine[];
    /** The number of decimal places to display for floating point numbers. */
    static uint8_t DecimalDigits;
    /** The character that represents a negative sign. */
    static char NegativeSign;
    /** The character that represents the decimal point. */
    static char DecimalSeparator;
    /** The default BaseTypes value to use when non is specified. */
    static uint8_t DefaultBase;
};
