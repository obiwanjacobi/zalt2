#ifndef __ASYNC_H__
#define __ASYNC_H__

#include <stdint.h>
// clang-format off

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
    uint16_t state;
    async_result_t result;
} async_t;

/** MACRO: Start an async block.
 */
#define Async_Begin()    \
    {                         \
        bool _yield_ = false; \
        (void)_yield_;        \
        async->result = asyncResult_Pending \
        switch (async->state)        \
        {                     \
        case 0:

/** MACRO: Declare the end of the async block
 */
#define Async_End()\
    }            \
    async->state = 0;   \
    async->result = asyncResult_None

/** MACRO: Exits the Task procedure immediately.
 *  \return Returns retVal from the Task procedure.
 */
#define Async_Return(retVal) \
    async->state = 0;        \
    async->result = asyncResult_None \
    return retVal;

/** Asynchronously waits for the expression to become true.
 *  The expression is evaluated before the Task procedure is exited.
 *  \return Returns false from the Task procedure.
 */
#define Async_WaitUntil(expression, retValWait) \
    async->state = __LINE__; case __LINE__:  \
        if (!(expression)) { return retValWait; }

/** MACRO: Yields from the Task procedure until the expression evaluates to true.
 *  The Task procedure is yielded (exited) first and on reentry is the expression evaluated.
 *  \return Returns false from the Task procedure.
 */
#define Async_YieldUntil(expression, retValYield)   \
    _yield_ = true;                   \
    async->state = __LINE__; case __LINE__:  \
        if (_yield_ || !(expression)) { return retValYield; }

/** MACRO: Yields from the Task procedure.
 *  The Task procedure is yielded (exited) first and on reentry is the procedure resumed.
 *  \return Returns false from the Task procedure.
 */
#define Task_Yield(retValYield) \
    Task_YieldUntil(true, retValYield)

#endif  //__ASYNC_H__