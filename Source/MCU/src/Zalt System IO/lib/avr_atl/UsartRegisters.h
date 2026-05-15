#pragma once
#include <stdint.h>
#include <avr/io.h>

/** Indicates the available Usart ports.
 *  Availablilty is based on the presence of the UBRR register.
 */
enum class UsartIds
{
/** Usart 0 */
#ifdef UBRR0
    Usart0,
#endif
/** Usart 1 */
#ifdef UBRR1
    Usart1
#endif
    // Usart2,
    // Usart3,
};

/** The UsartRegisters class is a static class (that cannot be instantiated)
 *  that knows what the registers are for the various Usart ports.
 *  \tparam UsartId indicates the Usart port.
 */
template <const UsartIds UsartId>
class UsartRegisters
{
public:
    /** Usart Baud Rate Register
     *  \return Returns a reference to the register.
     */
    static volatile uint16_t &getUBRR()
    {
        return _SFR_MEM16(0xC4 + ((uint8_t)UsartId * 0x08));
    }

    /** Usart Control and Status Register A
     *  \return Returns a reference to the register.
     */
    static volatile uint8_t &getUCSRA()
    {
        return _SFR_MEM8(0xC0 + ((uint8_t)UsartId * 0x08));
    }

    /** Usart Control and Status Register B
     *  \return Returns a reference to the register.
     */
    static volatile uint8_t &getUCSRB()
    {
        return _SFR_MEM8(0xC1 + ((uint8_t)UsartId * 0x08));
    }

    /** Usart Control and Status Register C
     *  \return Returns a reference to the register.
     */
    static volatile uint8_t &getUCSRC()
    {
        return _SFR_MEM8(0xC2 + ((uint8_t)UsartId * 0x08));
    }

    /** Usart Data Register
     *  \return Returns a reference to the register.
     */
    static volatile uint8_t &getUDR()
    {
        return _SFR_MEM8(0xC6 + ((uint8_t)UsartId * 0x08));
    }
};