#ifndef __ASYNC_H__
#define __ASYNC_H__

#include <stdint.h>
// clang-format off

//
// Async
//

const uint8_t asyncResult_None = 0;
const uint8_t asyncResult_Pending = 1;
const uint8_t asyncResult_Success = 2;
const uint8_t asyncResult_Failure = 3;
typedef uint8_t async_result_t;

/**
 *  Async structure.
 *  Represents the state and result (outcome) of an async procedure.
 *
 *  \code
 *  Async_Begin(MyAsyncProc)
 *      Async_WaitUntil(<condition>);
 *  Async_End()
 * 
 *  async_t myAsync;
 *  Async_Init(myAsync);
 *  ...
 *  if (MyAsyncProc(&myAsync))
 *  {
 *      // Async procedure has exited
 *  }
 *  \endcode
 * 
 *  \note This structure should be initialized before use.
 *  \note The 'state' field is used internally to track the progress of the async procedure.
 *  \note The 'result' field indicates the outcome of the async procedure.
 * 
 *  Extend this strucure to include additional information specific to your async procedure.
 *  
 *  \code
 *  typedef struct
 *  {
 *      // Include the async structure as the first member
 *      async_t async;
 * 
 *      // Add additional fields here
 *      ...
 *  } my_async_t;
 *  \endcode
 */
typedef struct
{
    uint16_t state;
    async_result_t result;
} async_t;

/** MACRO: Async_Init to initialze an async_t instance.
 *  \param async The async_t instance to initialize.
 */
#define Async_Init(async) MEM_CLEAR(async)

/** MACRO: Declares an async procedure 'name'.
 *  bool <name>(async_t *async) {...}
 *  \param name The name of the async procedure.
 *  \return Returns an indication if the async procedure has yielded (false) or exited (true).
 */
#define Async_Begin(name)  \
    bool name(asynt_t *async)   \
    {                         \
        bool _yield_ = false; \
        (void)_yield_;        \
        async->result = asyncResult_Pending; \
        switch (async->state)        \
        {                     \
        case 0:

/** MACRO: Declares an async procedure 'name' with parameters.
 *  bool <name>(async_t *async, ...params) {...}
 *  \param name The name of the async procedure.
 *  \param params The parameters of the async procedure.
 *  \return Returns an indication if the async procedure has yielded (false) or exited (true).
 */
#define Async_BeginParams(name, params...) \
    bool name(async_t *async, params)      \
    {                               \
        bool _yield_ = false;       \
        (void)_yield_;              \
        async->result = asyncResult_Pending; \
        switch (async->state)       \
        {                           \
        case 0:

/** MACRO: Declare the end of the async procedure.
 *  The async procedure will be marked as success.
 *  \return Returns true from the async procedure.
 */
#define Async_End() \
        }           \
        async->state = 0;   \
        async->result = asyncResult_Success;  \
        return true;        \
    }

/** MACRO: Exits the async procedure immediately.
 *  The async procedure will be marked as success.
 *  \return Returns true from the async procedure.
 */
#define Async_Return() \
    async->state = 0;  \
    async->result = asyncResult_Success \
    return true;

/** MACRO: Exits the async procedure immediately.
 *  The async procedure will be marked as failed.
 *  \return Returns true from the async procedure.
 */
#define Async_Error() \
    async->state = 0; \
    async->result = asyncResult_Failure \
    return true;

/** Asynchronously waits for the expression to become true.
 *  The async procedure will continue to yield until the expression evaluates to true.
 *  \param expression The expression to evaluate.
 *  \return Returns false from the async procedure if expression is not true.
 */
#define Async_WaitUntil(expression) \
    async->state = __LINE__; case __LINE__:  \
        if (!(expression)) { return false; }

/** MACRO: Yields from the async procedure until the expression evaluates to true.
 *  The async procedure is yielded (returns false) first and on reentry is the expression evaluated.
 *  \param expression The expression to evaluate.
 *  \return Returns false from the async procedure if expression is not true.
 */
#define Async_YieldUntil(expression) \
    _yield_ = true;                  \
    async->state = __LINE__; case __LINE__:  \
        if (_yield_ || !(expression)) { return false; }

/** MACRO: Yields from the async procedure.
 *  The async procedure is yielded (returns false) first and on reentry is the procedure resumed.
 *  \return Returns false from the async procedure.
 */
#define Async_Yield() \
    Async_YieldUntil(true)

#endif  //__ASYNC_H__