#pragma once

/**
 * calls BaseT::Read()
 * The return type of BaseT::Read() must be (compatible with) T.
 */
template <class BaseT, typename T>
class ReadWithState : public BaseT
{
public:
    ReadWithState()
    {
        _state = BaseT::Read();
    }
    ReadWithState(T initialState)
    {
        _state = initialState;
    }

    /**
     * Returns true when a new state has been read.
     */
    bool TryRead(T *outState)
    {
        T current = BaseT::Read();
        if (current != _state)
        {
            _state = current;
            *outState = current;
            return true;
        }

        return false;
    }

    bool TryTryRead(T *outState)
    {
        T current = 0;
        if (BaseT::TryRead(&current) && current != _state)
        {
            _state = current;
            *outState = current;
            return true;
        }

        return false;
    }

    T getState() const
    {
        return _state;
    }

private:
    T _state;
};