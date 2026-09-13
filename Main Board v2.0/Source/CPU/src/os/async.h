#ifndef __ASYNC_H__
#define __ASYNC_H__

#include <stdint.h>
// clang-format off

//
// Async
//

const uint8_t asyncResult_None = 0;
const uint8_t asyncResult_Pending = 1;
const uint8_t asyncResult_Completed = 2;
const uint8_t asyncResult_Error = 3;
const uint8_t asyncResult_StateError = 4;
typedef uint8_t async_result_t;

/**
 *  Async structure.
 *  Represents the state and result (outcome) of an async procedure.
 *
 *  \note If you see any these warnings (or similar), you need to relocate the async proc code to the beginning of the file:
 *  "warning: large integer implicitly truncated to unsigned type" or "warning: case label value exceeds maximum value for type"
 * 
 *  \code
 *  Async_Begin(MyAsyncProc)
 *      Async_WaitUntil(<condition>);
 *  Async_End
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
    uint8_t state;
    async_result_t result;
} async_t;

/** MACRO: Async_Init to initialze an async_t instance.
 *  Will use 'sizeof()' to determine the size of the async_t instance, so it supports 'derived' structures.
 *  \param async The async_t instance to initialize.
 * 
 *  \code
 *  async_t myAsync;
 *  Async_Init(myAsync);
 *  \endcode
 */
#define Async_Init(async) MEM_CLEAR(async)

/** MACRO: Declares an async procedure 'name'.
 *  bool <name>(async_t *async) {...}
 *  \param name The name of the async procedure.
 *  \return Returns an indication if the async procedure has yielded (false) or exited (true).
 */
#define Async_Begin(name)  \
    bool_t name(async_t *async)   \
    {                         \
        bool_t _yield_ = false; \
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
#define Async_BeginParams(name, params) \
    bool_t name(async_t *async, params)      \
    {                               \
        bool_t _yield_ = false;       \
        (void)_yield_;              \
        async->result = asyncResult_Pending; \
        switch (async->state)       \
        {                           \
        case 0:

/** MACRO: Declare the end of the async procedure.
 *  Implements the default case for the async procedure state machine (StateError).
 *  The async procedure will be marked as completed.
 *  \return Returns true from the async procedure.
 */
#define Async_End \
        default:    \
            async->result = asyncResult_StateError;  \
            return true;        \
        }           \
        async->state = 0;   \
        async->result = asyncResult_Completed;  \
        return true;        \
    }

/** MACRO: Exits the async procedure immediately.
 *  The async procedure will be marked as completed.
 *  \return Returns true from the async procedure.
 */
#define Async_Return() \
    async->state = 0;  \
    async->result = asyncResult_Completed; \
    return true;

/** MACRO: Exits the async procedure immediately.
 *  The async procedure will remain marked as pending.
 *  Use in case the (logical) operation is not done yet, 
 *  but you want to run from the start of the async procedure again (state = 0).
 *  \return Returns false from the async procedure.
 */
#define Async_Continue() \
    async->state = 0;  \
    return false;

/** MACRO: Exits the async procedure immediately.
 *  The async procedure will be marked as error.
 *  \return Returns true from the async procedure.
 */
#define Async_Error() \
    async->state = 0; \
    async->result = asyncResult_Error; \
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