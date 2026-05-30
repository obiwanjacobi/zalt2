#include "./types.h"

relptr_t RelativePtr_Construct(relptr_t *relPtr, ptr_t ptr)
{
    if (ptr == nullptr)
    {
        *relPtr = 0;
        return 0;
    }
    *relPtr = (uint8_t *)ptr - (uint8_t *)relPtr;
    return *relPtr;
}

ptr_t RelativePtr_ToPointer(relptr_t *relPtr)
{
    return (ptr_t)(relPtr + *relPtr);
}
