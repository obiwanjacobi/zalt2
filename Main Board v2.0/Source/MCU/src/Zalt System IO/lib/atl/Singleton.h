#pragma once

/** Makes BaseT a singleton: one global instance
 *  \tparam BaseT is the type that becomes a singleton.
 */
template <typename BaseT>
class Singleton
{
public:
    static BaseT *getCurrent() { return _instance; }

    Singleton()
    {
        // assert(_instance == nullptr);
        _instance = (BaseT *)this;
    }

private:
    static BaseT *_instance;
};

template <typename BaseT>
BaseT *Singleton<BaseT>::_instance = nullptr;
