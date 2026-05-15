#pragma once
#include <stdint.h>
#include <avr/eeprom.h>
#include "atl/LockScope.h"

// - add brown-out detector to prevent corruption due to low vcc
// -

/** Provides a safe interface to the EEPROM (disables interrupts on access).
 *  The EEPROM is a non-volatile memory that can be used to store data that must be preserved between resets.
 *  The EEPROM is organized in bytes and can be read and written byte by byte.
 *  The EEPROM is slow to write so you may want to do other things in between write operations.
 *  The EEPROM is limited to a number of write cycles so you should avoid writing to it too often.
 *  The EEPROM is limited to a number of write cycles so you should avoid writing to it too often.
 *  \tparam Address The address in the EEPROM where the data will be stored.
 */
template <const uint8_t Address>
class Eeprom
{
public:
    /** Indicates if the EEPROM is ready to accept a write operation.
     *  EEPROM io takes long so you may wanto to do other things in between.
     *  \return true if the EEPROM is ready to accept a write operation.
     */
    static bool IsReady()
    {
        LockScope lock;
        return eeprom_is_ready();
    }

    static void Write8(const uint8_t value)
    {
        LockScope lock;
        eeprom_update_byte((uint8_t *)Address, value);
    }

    static void Write16(const uint16_t value)
    {
        LockScope lock;
        eeprom_update_word((uint16_t *)Address, value);
    }

    static void Write32(const uint32_t value)
    {
        LockScope lock;
        eeprom_update_dword((uint32_t *)Address, value);
    }

    static void WriteFloat(const float value)
    {
        LockScope lock;
        eeprom_update_float((float *)Address, value);
    }

    static void Write(const uint8_t *buffer, const uint16_t size)
    {
        LockScope lock;
        eeprom_update_block(buffer, (void *)Address, size);
    }

    template <typename T>
    static void Write(const T *structure)
    {
        LockScope lock;
        eeprom_update_block(structure, (void *)Address, sizeof(T));
    }

    static uint8_t Read8()
    {
        LockScope lock;
        return eeprom_read_byte((const uint8_t *)Address);
    }

    static uint16_t Read16()
    {
        LockScope lock;
        return eeprom_read_word((const uint16_t *)Address);
    }

    static uint32_t Read32()
    {
        LockScope lock;
        return eeprom_read_dword((const uint32_t *)Address);
    }

    static float ReadFloat()
    {
        LockScope lock;
        return eeprom_read_float((const float *)Address);
    }

    static void Read(uint8_t buffer, const uint16_t size)
    {
        LockScope lock;
        eeprom_read_block(buffer, (const void *)Address, size);
    }

    template <typename T>
    static void Read(T *structure)
    {
        LockScope lock;
        eeprom_read_block(structure, (const void *)Address, sizeof(T));
    }

private:
    Eeprom() {}
};