#pragma once
#include <stdint.h>

/** Math provides math functions.
 *  The Math class is a static class and cannot be instantiated.
 */
class Math
{
public:
    /** Returns the absolute value.
     *  \tparam T is the data type of the value.
     *  \param value is the value to return the non-negative representation for.
     *  \return Returns the non-negative value.
     */
    template <typename T>
    static T Abs(T value)
    {
        return value >= 0 ? value : -value;
    }

    template <typename InT, typename OutT>
    static OutT ScaleLinear(InT minIn, InT maxIn, OutT minOut, OutT maxOut, InT value)
    {
        // Handle edge cases
        if (minIn == maxIn)
            return (minOut + maxOut) / 2;

        // Clamp input value to the input range
        if (value <= minIn)
            return minOut;
        if (value >= maxIn)
            return maxOut;

        // Use int32_t for intermediate calculations to avoid overflow
        int32_t numerator = (int32_t)(value - minIn) * (maxOut - minOut);
        int32_t denominator = (maxIn - minIn);

        return minOut + (OutT)(numerator / denominator);
    }

private:
    Math() {}
};