#pragma once
#include <stdint.h>

/** Represents a bounds-checked (read-only) array.
 *  \tparam T is the type of the array items.
 *  \tparam MaxItems is the maximum number of items in the array.
 */
template <typename T, const int16_t MaxItems>
class Array
{
public:
    /** ItemT defines the type of array items.
     */
    typedef T ItemT;

    /** Gets the maximum number of items the array can store.
     *  \return Returns the MaxItems template parameter.
     */
    uint16_t getCapacity() const
    {
        return MaxItems;
    }

    /** Gets the current number of items in the array.
     *  \return Returns the MaxItems template parameter.
     */
    uint16_t getCount() const
    {
        return MaxItems;
    }

    /** Gets the item at the zero-based index position.
     *  If the specified index is invalid a default value for T is returned. See also Default<T>::DefaultOfT.
     *  \param index is a zero-based index that has to be greater or equal to 0 (zero) and smaller than MaxItems.
     *  \return Returns the item or a default value.
     */
    const T GetAt(int16_t index) const
    {
        if (index < 0)
            return _arr[0];
        if (index >= MaxItems)
            return _arr[MaxItems - 1];

        return _arr[index];
    }

    /** Indicates if the specified index is valid for the array.
     *  \param index is a zero-based index that has to be greater or equal to 0 (zero) and smaller than MaxItems.
     *  \return Returns true when the index is valid, otherwise false.
     */
    bool IsValidIndex(int16_t index) const
    {
        return index >= 0 && index < MaxItems;
    }

    /** Finds the index of the first matching item in the array.
     *  Be careful with arrays that contain duplicate items.
     *  \param item is the item to search for.
     *  \return Returns the index of the position of the item in the array, or -1 if not found.
     */
    int16_t IndexOf(T item) const
    {
        for (int16_t i = 0; i < MaxItems; i++)
        {
            if (_arr[i] == item)
                return i;
        }

        return -1;
    }

    /** Gets the item at the zero-based index position.
     *  If the specified index is invalid a default value for T is returned. See also Default<T>::DefaultOfT.
     *  \param index is a zero-based index that has to be greater or equal to 0 (zero) and smaller than MaxItems.
     *  \return Returns the item or a default value.
     */
    const T operator[](int16_t index) const
    {
        return GetAt(index);
    }

    operator const T *() const
    {
        return _arr;
    }

    /** Provides access to the internal buffer that stores the items in the array.
     *  Not recommended to use this because no bounds checking is performed.
     *  \return Returns the pointer to the buffer.
     */
    T *getBuffer()
    {
        return _arr;
    }

private:
    T _arr[MaxItems];
};