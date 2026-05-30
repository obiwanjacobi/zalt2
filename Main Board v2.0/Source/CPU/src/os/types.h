#ifndef __TYPES_H__
#define __TYPES_H__

#include <stdint.h>

// IntelliSense may not always pick up z88dk calling-convention macros.
// Keep declarations parseable when SCCZ80/SDCC is selected.
#if defined(__SDCC) || defined(__SCCZ80)
    #ifndef __z88dk_fastcall
        #define __z88dk_fastcall
    #endif
    #ifndef __z88dk_callee
        #define __z88dk_callee
    #endif
#endif

// FastCall for C calls with one parameter
// FastAPI for asm calls with one parameter
// API for asm calls/adaptors (cannot not be pointed to!)
// - omit macro when function pointer is needed
#if defined(__SDCC) || defined(__SCCZ80)
    #define FastCall(fn) fn __z88dk_fastcall
    #define FastApi(fn) fn __z88dk_fastcall
    #define Api(fn) fn __z88dk_callee
#else
    // mainly for IDE
    #define FastCall(fn) fn
    #define FastApi(fn) fn
    #define Api(fn) fn
#endif

typedef uintptr_t ptr_t;
#define nullptr ((void*)0)

//
// Relative Pointer
//

typedef uint16_t relptr_t;

/// Constructs a relative ptr (relPtr) based on the passed regular ptr. Returns the relPtr value.
relptr_t RelativePtr_Construct(relptr_t *relPtr, ptr_t ptr);
/// Returns a regular ptr for the relative ptr.
ptr_t FastCall(RelativePtr_ToPointer)(relptr_t *relPtr);

//
// Slice
//

typedef struct {
    ptr_t ptr;
    uint16_t len;
} slice;

//
// Async
//

typedef enum
{
    asyncResult_None,
    asyncResult_Pending,
    asyncResult_Completed,
    asyncResult_Error,
} async_result_t;

typedef struct
{
    uint16_t State;
    async_result_t Result;
} async_t;

#endif //__TYPES_H__
