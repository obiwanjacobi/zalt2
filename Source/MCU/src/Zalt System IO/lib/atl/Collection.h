#pragma once
#include "DefaultOfT.h"

/** The Collection class implements dynamic behavior of adding items on top of a FixedArray.
 *  \tparam ArrayT is the array type that is used to store the actual items.
 *  ArrayT implements `T GetAt(int16_t index)`, `void SetAt(int16_t index, T item)` and `uint16_t getCapacity()`.
 */
template <typename ArrayT>
class Collection
{
public:
    /** The datatype of the items in the collection. */
    typedef typename ArrayT::ItemT ItemT;

    /** Constructs a new instance.
     */
    Collection()
        : _count(0)
    {
    }

    /** Constructs an initialized instance.
     *  \param array points to the items the array will be initialized with. The Capacity of the array must be adaquate.
     */
    Collection(ItemT *array)
        : _array(array), _count(0)
    {
    }

    /** Gets the maximum number of items the collection can store.
     *  \return Returns the Capacity of the underlying array.
     */
    int16_t getCapacity() const
    {
        return _array.getCapacity();
    }

    /** Gets the current number of items in the collection.
     *  \return Returns the count.
     */
    int16_t getCount() const
    {
        return _count;
    }

    /** Indicates if the specified index is valid for the array.
     *  \param index is a zero-based index that has to be greater or equal to 0 (zero) and smaller than the count.
     *  \return Returns true when the index is valid, otherwise false.
     */
    bool IsValidIndex(int16_t index) const
    {
        return index >= 0 && (uint16_t)index < _count;
    }

    /** Finds the index of the first matching item in the collection.
     *  Be careful with collections that contain duplicate items.
     *  \param item is the item to search for.
     *  \return Returns the index of the position of the item in the collection, or -1 if not found.
     */
    int16_t IndexOf(ItemT item) const
    {
        for (int16_t i = 0; i < (int16_t)_count; i++)
        {
            if (_array.GetAt(i) == item)
                return i;
        }

        return -1;
    }

    /** Gets the item at the zero-based index position.
     *  If the specified index is invalid a default value for T is returned. See also Default<T>::DefaultOfT.
     *  \param index is a zero-based index that has to be greater or equal to 0 (zero) and smaller than the count.
     *  \return Returns the item or a default value.
     */
    ItemT GetAt(int16_t index) const
    {
        if (!IsValidIndex(index))
            return Default<ItemT>::DefaultOfT;

        return _array.GetAt(index);
    }

    /** Gets the item at the zero-based index position.
     *  If the specified index is invalid a default value for T is returned. See also Default<T>::DefaultOfT.
     *  \param index is a zero-based index that has to be greater or equal to 0 (zero) and smaller than the count.
     *  \return Returns the item or a default value.
     */
    ItemT operator[](int16_t index) const
    {
        return GetAt(index);
    }

    operator const ItemT *() const
    {
        return _array;
    }

    /** Adds a new item at the end of the collection.
     *  Does nothing when the collection is full.
     *  \param item is the item to add. Will add NULL.
     */
    bool Add(ItemT item)
    {
        if (_count < _array.getCapacity())
        {
            _array.SetAt(_count, item);
            _count++;
            return true;
        }

        return false;
    }

    /** Sets a new item at the specified index.
     *  Does nothing when the index is not valid.
     *  \param index is the position in the collection that gets overwritten with the new item.
     *  \param item is the new value to store at the index position.
     */
    bool SetAt(int16_t index, ItemT item)
    {
        if (!IsValidIndex(index))
            return false;

        _array.SetAt(index, item);
        return true;
    }

    /** Clears the content of the collection.
     */
    void Clear()
    {
        _count = 0;
        _array.Clear();
    }

    /** Gets the pointer to the internal array buffer.
     */
    ItemT *getBuffer()
    {
        return _array.getBuffer();
    }

private:
    ArrayT _array;
    uint16_t _count;
};
