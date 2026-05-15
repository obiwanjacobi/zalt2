#pragma once

/** Adds an Id to any class.
 *  Typically used by the Task macros and the Delays class to identify the owner of registered delays.
 *  \tparam BaseT is for convenience and not used by this class.
 */
template <class BaseT>
class IdentifiableObject : public BaseT
{
public:
    /** Returns an id based on the this pointer.
     *  \return Returns a unique id.
     */
    uint16_t getId() const
    {
        return (uint16_t)this;
    }
};