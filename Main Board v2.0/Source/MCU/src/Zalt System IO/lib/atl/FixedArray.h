#pragma once
#include <stdint.h>
#include "Array.h"

/** The FixedArray adds methods that change the Array.
 *  Fixed refers to its size, it's predetermined when it is constructed.
 *  \tparam T the datatype of the items in the array.
 *  \tparam MaxItems is the maximum number of items in the array.
 */
template <typename T, const int16_t MaxItems>
class FixedArray : public Array<T, MaxItems>
{
    typedef Array<T, MaxItems> BaseT;

public:
    /** ItemT defines the type of array items.
     */
    typedef T ItemT;

    /** Assigns the item to the specified position (index).
     *  Does nothing when the index is invalid.
     *  \param index is a zero-based index that has to be greater or equal to 0 (zero) and smaller than MaxItems.
     *  \param item is the new value for the position indicated by index.
     */
    void SetAt(int16_t index, T item)
    {
        if (!BaseT::IsValidIndex(index))
            return;

        BaseT::getBuffer()[index] = item;
    }

    /** Retrieves the (writable) item (reference) for the specified position (index).
     *  Clips the index to a valid range and returns that item.
     *  \param index is a zero-based index that has to be greater or equal to 0 (zero) and smaller than MaxItems.
     *  \return Returns the item value for the position indicated by index. The return value for an invalid index is undetermined.
     */
    T &operator[](int16_t index)
    {
        T *arr = BaseT::getBuffer();

        if (index < 0)
            return arr[0];
        if (index >= MaxItems)
            return arr[MaxItems - 1];

        return arr[index];
    }

    /** Clears the memory occupied by the array.
     *  All bytes are reset to 0 (zero).
     */
    void Clear()
    {
        memset(BaseT::getBuffer(), 0, MaxItems);
    }
};
