#pragma once
#include <stdint.h>

/** Manipulates a single bit in a variable.
 *  Bit is a static class, meaning that no instance can be constructed.
 *  All methods are called like `Bit<2>::Set(myVar);` which would set bit2 in myVar.
 *  Use BitFlag instead of Bit when the bitIndex is dynamic/only known at runtime.
 *  Bit is slightly more optimal when the bitIndex is known at compile time (hard-coded).
 *  \tparam BitIndex is the zero-based index where 0 is the least significant bit.
 */
template <const uint8_t BitIndex>
class Bit
{
public:
    /** Sets (true) the BitIndex bit in the target variable.
     *  \tparam T the data type of the target variable.
     *  \param target the variable that will be changed.
     */
    template <typename T>
    static void Set(T &target)
    {
        target |= getMask<T>();
    }

    /** Sets the BitIndex bit in the target variable to the specified value.
     *  \tparam T the data type of the target variable.
     *  \param target the variable that will be changed.
     *  \param value specifies the value for the bit at BitIndex.
     */
    template <typename T>
    static void Set(T &target, bool value)
    {
        T mask = getMask<T>();

        if (value)
        {
            // set bit
            target |= mask;
        }
        else
        {
            // clear bit
            target &= ~mask;
        }
    }

    /** Clears (false) the BitIndex bit in the target variable.
     *  \tparam T the data type of the target variable.
     *  \param target the variable that will be changed.
     */
    template <typename T>
    static void Clear(T &target)
    {
        // clear bit
        target &= ~getMask<T>();
    }

    /** Toggles (inverts) the BitIndex bit in the target variable.
     *  \tparam T the data type of the target variable.
     *  \param target the variable that will be changed.
     */
    template <typename T>
    static void Toggle(T &target)
    {
        target ^= getMask<T>();
    }

    /** Indicates if the BitIndex bit in the target variable is a one (true).
     *  \tparam T the data type of the target variable.
     *  \param target the variable that contains the bit.
     */
    template <typename T>
    static bool IsTrue(T target)
    {
        return (target & getMask<T>()) > 0;
    }

    /** Indicates if the BitIndex bit in the target variable is a zero (false).
     *  \tparam T the data type of the target variable.
     *  \param target the variable that contains the bit.
     */
    template <typename T>
    static bool IsFalse(T target)
    {
        return (target & getMask<T>()) == 0;
    }

    /** Calculates the bit mask for the BitIndex bit.
     *  \tparam T the data type of the target variable.
     *  \return Returns a value with the BitIndex'th bit set.
     */
    template <typename T>
    constexpr static T getMask()
    {
        return 1 << BitIndex;
    }

private:
    Bit() {}
};

// ----------------------------------------------------------------------------

/** Manipulates a single bit in a variable.
 *  The BitFlag class has similar functionality as the Bit class.
 *  BitFlag is a static class, meaning that no instance can be constructed.
 *  All methods are called like `BitFlag::Set(myVar, 2);` which would set bit2 in myVar.
 *  Use BitFlag instead of Bit when the bitIndex is dynamic/only known at runtime.
 *  Bit is slightly more optimal when the bitIndex is known at compile time (hard-coded).
 */
class BitFlag
{
public:
    /** Sets (true) the bit at bitIndex in target.
     *  \tparam T the data type of the target variable.
     *  \param target the variable that will be changed.
     *  \param bitIndex is the zero-based index where the value bits are stored.
     */
    template <typename T>
    static void Set(T &target, const uint8_t bitIndex)
    {
        if (bitIndex >= getMaxBits<T>())
            return;

        target |= getMask<T>(bitIndex);
    }

    /** Sets the bit at bitIndex in target to the specified value.
     *  \tparam T the data type of the target variable.
     *  \param target the variable that will be changed.
     *  \param bitIndex is the zero-based index where the value bits are stored.
     *  \param value is the value to be stored.
     */
    template <typename T>
    static void Set(T &target, const uint8_t bitIndex, bool value)
    {
        if (bitIndex >= getMaxBits<T>())
            return;

        T mask = getMask<T>(bitIndex);

        if (value)
        {
            // set bit
            target |= mask;
        }
        else
        {
            // clear bit
            target &= ~mask;
        }
    }

    /** Resets (false) the bit at bitIndex in target.
     *  \tparam T the data type of the target variable.
     *  \param target the variable that will be changed.
     *  \param bitIndex is the zero-based index where the value bits are stored.
     */
    template <typename T>
    static void Reset(T &target, const uint8_t bitIndex)
    {
        if (bitIndex >= getMaxBits<T>())
            return;

        // clear bit
        target &= ~getMask<T>(bitIndex);
    }

    /** Toggles (inverts) the bit at bitIndex in target.
     *  \tparam T the data type of the target variable.
     *  \param target the variable that will be changed.
     *  \param bitIndex is the zero-based index where the value bits are stored.
     */
    template <typename T>
    static void Toggle(T &target, const uint8_t bitIndex)
    {
        if (bitIndex >= getMaxBits<T>())
            return;

        target ^= getMask<T>(bitIndex);
    }

    /** Indicates if the bit at bitIndex in target is set (true).
     *  \tparam T the data type of the target variable.
     *  \param target the variable that stores the bit value.
     *  \param bitIndex is the zero-based index where the value bits are stored.
     *  \return Returns true if the bit is set.
     */
    template <typename T>
    static bool IsTrue(T target, const uint8_t bitIndex)
    {
        if (bitIndex >= getMaxBits<T>())
            return false;

        return (target & getMask<T>(bitIndex)) > 0;
    }

    /** Indicates if the bit at bitIndex in target is reset (false).
     *  \tparam T the data type of the target variable.
     *  \param target the variable that stores the bit value.
     *  \param bitIndex is the zero-based index where the value bits are stored.
     *  \return Returns true if the bit is reset.
     */
    template <typename T>
    static bool IsFalse(T target, const uint8_t bitIndex)
    {
        if (bitIndex >= getMaxBits<T>())
            return false;

        return (target & getMask<T>(bitIndex)) == 0;
    }

    /** Retrieves the maximum number of bits that will fit into T.
     *  \tparam T the data type of the target variable.
     *  \return Returns the maximum number of bit positions.
     */
    template <typename T>
    static uint8_t getMaxBits()
    {
        return (sizeof(T) * __CHAR_BIT__);
    }

    /** Calculates the bit mask for the bitIndex bit.
     *  \tparam T the data type of the target variable.
     *  \param bitIndex is the zero-based index a mask is constructed for.
     *  \return Returns a value with the BitIndex'th bit set.
     */
    template <typename T>
    static T getMask(const uint8_t bitIndex)
    {
        return 1 << bitIndex;
    }

private:
    BitFlag() {}
};