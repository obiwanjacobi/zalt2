#pragma once
// clang-format off

/** \file Task.h
 *  The Task implementation is based on macros forming a switch statement.
 *  It is possible to jump in and out of switch-cases and together
 *  with a _task variable a Task can be 'resumed' at the correct
 *  position.
 *  Keep the logic inside the Task method simple for it can cause compile errors.
 *  Calling functions is no problem.
 *
 *  This code was taken from http://msdn.microsoft.com/en-us/magazine/jj553509.aspx
 *  It seems a lightweight way to implement cooperative multitasking.
 *  See Also TimeoutTask for an example.
 *  You MUST have an "uint16_t _task" (private) variable to store the task state (FSM).
 * 
 *  You can use "uint8_t _task" if you have a small source file or the Task method is at the top of the file.
 *  If you see any these warnings (or similar), you need to a larger data type for the _task variable:
 *  "warning: large integer implicitly truncated to unsigned type"
 *  "warning: case label value exceeds maximum value for type"
 */

/** MACRO: Declare a 'Task' procedure 'name'.
 *  \return Returns an indication if the task has yielded (false) or simply exited (true).
 */
// NOTE: You can get an 'unused variable _yield_' warning if you do not use the Yield-macros.
#define Task_Begin(name)      \
    bool name()               \
    {                         \
        bool _yield_ = false; \
        (void)_yield_;        \
        switch (_task)        \
        {                     \
        case 0:

/** MACRO: Declare a 'Task' procedure 'name' with parameters.
 *  \return Returns an indication if the task has yielded (false) or simply exited (true).
 */
// NOTE: You can get an 'unused variable _yield_' warning if you do not use the Yield-macros.
#define Task_BeginParams(name, args...) \
    bool name(args)                 \
    {                               \
        bool _yield_ = false;       \
        (void)_yield_;              \
        switch (_task)              \
        {                           \
        case 0:

/** MACRO: Declare the end of the 'Task' procedure
 *  Exits the task procedure.
 *  \return Returns true from the Task procedure.
 */
#define Task_End \
        }            \
        _task = 0;   \
        return true; \
    }                \

/** MACRO: Exits the Task procedure immediately.
 *  \return Returns true from the Task procedure.
 */
#define Task_Return() \
    _task = 0;        \
    return true;

/** Asynchronously waits for the expression to become true.
 *  The expression is evaluated before the Task procedure is exited.
 *  \return Returns false from the Task procedure.
 */
#define Task_WaitUntil(expression) \
    _task = __LINE__; case __LINE__:  \
        if (!(expression))         \
        {                          \
            return false;          \
        }

/** MACRO: Yields from the Task procedure until the expression evaluates to true.
 *  The Task procedure is yielded (exited) first and on reentry is the expression evaluated.
 *  \return Returns false from the Task procedure.
 */
#define Task_YieldUntil(expression)   \
    _yield_ = true;                   \
    _task = __LINE__; case __LINE__:  \
        if (_yield_ || !(expression)) \
        {                             \
            return false;             \
        }

/** MACRO: Yields from the Task procedure.
 *  The Task procedure is yielded (exited) first and on reentry is the procedure resumed.
 *  \return Returns false from the Task procedure.
 */
#define Task_Yield() \
    Task_YieldUntil(true)

