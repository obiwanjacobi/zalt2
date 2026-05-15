#pragma once
#include "Debug.h"

/** The Iterator class maintains a current index of the iteration position.
 *  It can move this position forward and backwards but does not wrap around the beginning or the end (See WrapAroundIterator).
 *  Either MoveNext, MoveBack or MoveTo methods must be called before there is a valid current item.
 *	\tparam BaseT is expected to implement the Array interface:
 *	`typedef ItemT` (the array item type)
 *	`ctor(const ItemT*)` (optional)
 *	`ItemT getDefaultItem() const`
 *	`IndexT IndexOf(ItemT) const`
 *	`ItemT GetAt(IndexT) const`
 *  `IndexT getCount() const`.
 */
template <class BaseT, typename IndexT = int8_t>
class Iterator : public BaseT
{
public:
    /** ItemT defines the type of array items.
     */
    typedef typename BaseT::ItemT ItemT;

    /** Constructs the instance.
     */
    Iterator() : _index(-1) {}

    /** Constructs an initialized instance (pass-through).
     *  \param array points to the (untyped) array that is passed to BaseT.
     */
    Iterator(const void *array)
        : BaseT(array), _index(-1) {}

    /** Moves to the next item.
     *  \return Returns true when successful.
     */
    bool MoveNext()
    {
        if (!IsValidIndex(_index + 1))
            return false;

        _index++;
        return true;
    }

    /** Moves to the previous item.
     *  \return Returns true when successful.
     */
    bool MoveBack()
    {
        if (!IsValidIndex(_index - 1))
            return false;

        _index--;
        return true;
    }

    /** Moves to the specified item.
     *  \param item is the item to find.
     *  \return Returns true when successful.
     */
    bool MoveTo(ItemT item)
    {
        IndexT i = BaseT::IndexOf(item);
        if (!IsValidIndex(i))
            return false;

        _index = i;
        return true;
    }

    /** Moves to the specified index.
     *  \param index is the new index.
     *  \return Returns true when successful.
     */
    bool MoveToIndex(IndexT index)
    {
        if (!IsValidIndex(index))
            return false;

        _index = index;
        return true;
    }

    /** Resets the current position to just before the beginning.
     *  Either MoveNext or MoveTo methods must be called before there is a valid current item.
     */
    void Reset()
    {
        _index = -1;
    }

    /** Indicates if the current position is valid.
     *  \return Returns true if valid.
     */
    bool getIsValidPosition() const
    {
        return IsValidIndex(_index);
    }

    /** Retrieves the item at the current position.
     *  \return Returns the item or a Default value if the current position is not valid.
     */
    ItemT getCurrent() const
    {
        if (!IsValidIndex(_index))
            return BaseT::getDefaultItem();

        return BaseT::GetAt(_index);
    }

    /** Retrieves the current position (index).
     *  \return Returns the index, can be invalid.
     */
    IndexT getCurrentIndex() const
    {
        return _index;
    }

protected:
    bool IsValidIndex(IndexT index) const
    {
        return index >= 0 && index < BaseT::getCount();
    }

    /** Resets the current position to just after the end.
     *  Either MoveBack or MoveTo methods must be called before there is a valid current item.
     */
    void ResetToEnd()
    {
        _index = BaseT::getCount();
    }

private:
    IndexT _index;
};

/** Implements wrap-around behavior on top of the Iterator class.
 *	\tparam BaseT is expected to implement the Array interface:
 *	`typedef ItemT` (the item type in the array)
 *	`ctor(const ItemT*)`
 *	`bool IsValidIndex(int16_t) const`
 *	`int16_t IndexOf(ItemT) const`
 *	`ItemT GetAt(int16_t) const`
 *  `uint16_t getCount() const`.
 */
template <typename BaseT>
class WrapAroundIterator : public Iterator<BaseT>
{
    typedef Iterator<BaseT> IteratorT;

public:
    /** Moves to the next item.
     *  Starts at the beginning when the end of the array is reached.
     *  \return Always returns true.
     */
    bool MoveNext()
    {
        if (!IteratorT::MoveNext())
        {
            IteratorT::Reset();
            IteratorT::MoveNext();
        }

        return true;
    }

    /** Moves to the previous item.
     *  Starts at the end when the beginning of the array is reached.
     *  \return Always returns true.
     */
    bool MoveBack()
    {
        if (!IteratorT::MoveBack())
        {
            IteratorT::ResetToEnd();
            IteratorT::MoveBack();
        }

        return true;
    }
};
