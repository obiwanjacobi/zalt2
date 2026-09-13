#ifndef __DEBUG_H__
#define __DEBUG_H__

#ifdef DEBUG

#include "async.h"
#include "error.h"

//
// clang-format off
//

//#define dAssert(c)                    if (!(c)) { System_DebugConsole_LogAssertFailed(__FILE__, __LINE__); dBreakpoint(); }
#define dGuard(c)                      if (c) { return; }
#define dGuardRetVal(c, v)             if (c) { return v; }
#define dGuardErr(c, e)                if (c) { Error_Set(e); return; }
#define dGuardErrRetVal(c, e, v)       if (c) { Error_Set(e); return v; }
//#define dLog(s)                        System_DebugConsole_Log(s);
//#define dLogIf(c, s)                   if (c) { System_DebugConsole_Log(s); }

#define dBreakpoint()               asm("rst 30h")

//
// clang-format on
//

#else //! DEBUG

#define dAssert(c)
#define dGuard(c)
#define dGuardVal(c, v)
#define dGuardErr(c, e)
#define dGuardErrVal(c, e, v)
#define dLog(s)
#define dLogIf(c, s)
#define dBreakpoint()

#endif // DEBUG

#endif //__DEBUG_H__
