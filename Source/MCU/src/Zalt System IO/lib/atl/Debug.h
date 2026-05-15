#pragma once
#include <stdint.h>

/** Indicates the debug logging level.
 *  Do not use Off.
 */
enum class DebugLevel : uint8_t
{
    /** Do not use. */
    Off,
    /** Indicates a critical error in the system. */
    Critical,
    /** Indicates an error in the system. */
    Error,
    /** Indicates a warning message. */
    Warning,
    /** Indicates a informational message. */
    Info,
    /** Indicates a trace message. */
    Trace,
    /** Indicates a message for debugging purposes. */
    Debug,
};

const uint8_t DebugAnonymousComponentId = 0x00;

#ifdef DEBUG

// Implement this method in your own code and route the message to the desired output.
void AtlDebugWrite(const uint8_t componentId, const DebugLevel level, const char *message) __attribute__((weak));

// Optionally implement this method in your own code and determine what debug level and components are debugged.
bool AtlDebugFilter(const uint8_t componentId, DebugLevel debugLevel) __attribute__((weak));

/** The Debug class allows conditionally writing messages from code to an unspecified target.
 *  The Debug class is a static class and cannot be instantiated.
 *  \tparam ComponentId is used as a source id for filtering debug log writes.
 */
template <const uint8_t ComponentId = DebugAnonymousComponentId>
class Debug
{
public:
    /** Logs the message to the debug target.
     *  \tparam DebugLevel indicates for which level the message is intended.
     *  Do not use `DebugLevel::Off`.
     *  \param message is the message text to write.
     */
    template <const DebugLevel DebugLevel>
    static void Log(const char *message)
    {
        static_assert(DebugLevel != DebugLevel::Off, "Debug::Log: Do not use DebugLevel::Off.");

        if (CanLog<DebugLevel>())
            AtlDebugWrite(ComponentId, DebugLevel, message);
    }

    /** Indicates if a message to the debug target for the specified ComponentId and debugLevel.
     *  \tparam DebugLevel indicates for which level the message is intended.
     *  Do not use `DebugLevel::Off`.
     *  \return Returns true if logging is enabled.
     */
    template <const DebugLevel DebugLevel>
    static bool CanLog()
    {
        static_assert(DebugLevel != DebugLevel::Off, "Debug::CanLog: Do not use DebugLevel::Off.");

        if (AtlDebugWrite == nullptr)
            return false;
        if (AtlDebugFilter == nullptr)
            return true;
        return AtlDebugFilter(ComponentId, DebugLevel);
    }

private:
    Debug() {}
};

#else // DEBUG

/** The Debug class for release builds is an empty class.
 *  The Debug class is a static class and cannot be instantiated.
 *  \tparam ComponentId is unused.
 */
template <const uint8_t ComponentId = DebugAnonymousComponentId>
class Debug
{
public:
    /** Does nothing.
     *  \tparam DebugLevel is not used.
     *  \param message is not used.
     */
    template <const DebugLevel DebugLevel>
    static void Log(const char * /*message*/) {}

    /** Always returns false.
     *  \tparam DebugLevel is not used.
     *  \return Returns false.
     */
    template <const DebugLevel DebugLevel>
    static bool CanLog() { return false; }

private:
    Debug() {}
};

#endif // ~DEBUG

void LogCritical(const char *message)
{
    Debug<>::Log<DebugLevel::Critical>(message);
}
template <const uint8_t ComponentId>
void LogCritical(const char *message)
{
    Debug<ComponentId>::template Log<DebugLevel::Critical>(message);
}

void LogError(const char *message)
{
    Debug<>::Log<DebugLevel::Error>(message);
}
template <const uint8_t ComponentId>
void LogError(const char *message)
{
    Debug<ComponentId>::template Log<DebugLevel::Error>(message);
}

void LogWarning(const char *message)
{
    Debug<>::Log<DebugLevel::Warning>(message);
}
template <const uint8_t ComponentId>
void LogWarning(const char *message)
{
    Debug<ComponentId>::template Log<DebugLevel::Warning>(message);
}

void LogInfo(const char *message)
{
    Debug<>::Log<DebugLevel::Info>(message);
}
template <const uint8_t ComponentId>
void LogInfo(const char *message)
{
    Debug<ComponentId>::template Log<DebugLevel::Info>(message);
}

void LogTrace(const char *message)
{
    Debug<>::Log<DebugLevel::Trace>(message);
}
template <const uint8_t ComponentId>
void LogTrace(const char *message)
{
    Debug<ComponentId>::template Log<DebugLevel::Trace>(message);
}

void LogDebug(const char *message)
{
    Debug<>::Log<DebugLevel::Debug>(message);
}
template <const uint8_t ComponentId>
void LogDebug(const char *message)
{
    Debug<ComponentId>::template Log<DebugLevel::Debug>(message);
}
