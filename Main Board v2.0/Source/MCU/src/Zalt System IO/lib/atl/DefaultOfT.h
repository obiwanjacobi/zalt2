#pragma once

/** Static default values of T;
 *  \tparam T is the type to get the default value for.
 */
template <typename T>
class Default
{
public:
    /** A statically initialized default value of T.
     *  Treat as read-only.
     */
    static T DefaultOfT;
};

template <typename T>
T Default<T>::DefaultOfT;