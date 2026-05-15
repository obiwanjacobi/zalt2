#pragma once
#include <stdint.h>
#include <avr/io.h>
#include <avr/interrupt.h>
#include "Bit.h"

enum class Ports : uint8_t
{
    None = 0,
#ifdef PORTA
    A = 0x08,
#endif // PORTA
#ifdef PORTB
    B = 0x10,
#endif // PORTB
#ifdef PORTC
    C = 0x18,
#endif // PORTC
#ifdef PORTD
    D = 0x20,
#endif // PORTC
#ifdef PORTE
    E = 0x28,
#endif // PORTE
#ifdef PORTF
    F = 0x30,
#endif // PORTF
#ifdef PORTG
    G = 0x38,
#endif // PORTG
#ifdef PORTH
    H = 0x40,
#endif // PORTH
#ifdef PORTJ
    J = 0x48,
#endif // PORTJ
#ifdef PORTK
    K = 0x50,
#endif // PORTK
#ifdef PORTL
    L = 0x58,
#endif // PORTL
};

enum PinIO : uint8_t
{
    Input,
    Output
};

enum class Pins : uint8_t
{
    Pin0 = 0,
    Pin1 = 1,
    Pin2 = 2,
    Pin3 = 3,
    Pin4 = 4,
    Pin5 = 5,
    Pin6 = 6,
    Pin7 = 7
};

// clang-format off
enum class PortPins : uint8_t
{
    None = 0,
#ifdef PORTA
    A0 = 0x08, A1, A2, A3, A4, A5, A6, A7,
#endif // PORTA
#ifdef PORTB
    B0 = 0x10, B1, B2, B3, B4, B5, B6, B7,
#endif // PORTB
#ifdef PORTC
    C0 = 0x18, C1, C2, C3, C4, C5, C6, C7,
#endif // PORTC
#ifdef PORTD
    D0 = 0x20, D1, D2, D3, D4, D5, D6, D7,
#endif // PORTD
#ifdef PORTE
    E0 = 0x28, E1, E2, E3, E4, E5, E6, E7,
#endif // PORTE
#ifdef PORTF
    F0 = 0x30, F1, F2, F3, F4, F5, F6, F7,
#endif // PORTF
#ifdef PORTG
    G0 = 0x38, G1, G2, G3, G4, G5, G6, G7,
#endif // PORTG
#ifdef PORTH
    H0 = 0x40, H1, H2, H3, H4, H5, H6, H7,
#endif // PORTH
#ifdef PORTJ
    J0 = 0x48, J1, J2, J3, J4, J5, J6, J7,
#endif // PORTJ
#ifdef PORTK
    K0 = 0x50, K1, K2, K3, K4, K5, K6, K7,
#endif // PORTK
#ifdef PORTL
    L0 = 0x58, L1, L2, L3, L4, L5, L6, L7,
#endif // PORTL
};
// clang-format on

#define TO_PORT(portPin) ((Ports)((uint8_t)portPin & 0xF8))
#define TO_PIN(portPin) ((Pins)((uint8_t)portPin & 0x07))
#define TO_PORTPIN(port, pin) ((PortPins)((uint8_t)port | (uint8_t)pin))

// ----------------------------------------------------------------------------

template <const Ports PortId>
class PortRegisters
{
    static_assert(PortId != Ports::None, "PortRegisters<PortId> is set to an ivalid value (Ports::None).");

// get from port id to register memory address
#define PortAddress ((((uint8_t)PortId >> 3) - 1) * 3)

public:
    static volatile uint8_t &In()
    {
        return _SFR_IO8(PortAddress);
    }

    static volatile uint8_t &Dir()
    {
        return _SFR_IO8(PortAddress + 1);
    }

    static volatile uint8_t &Out()
    {
        return _SFR_IO8(PortAddress + 2);
    }

private:
    PortRegisters() {}
};

// ----------------------------------------------------------------------------

/*
 *
 */
template <const Ports PortId>
class Port
{
    static_assert(PortId != Ports::None, "Port<PortId> is set to an invalid value (Ports::None).");

public:
    // Enables the internal pull-up for inputs.
    // Returns false when pin is not an input.
    static bool EnablePullup(Pins pin, bool enable = true)
    {
        uint8_t mask = BitFlag::getMask<uint8_t>((uint8_t)pin);

        if ((PortRegisters<PortId>::Dir() & mask) == Input)
        {
            PortRegisters<PortId>::Out() |= mask;
            return true;
        }

        return false;
    }

    static void EnableAllPullups(bool enable = true)
    {
        if (enable)
            PortRegisters<PortId>::Out() = ~PortRegisters<PortId>::Dir();
        else
            PortRegisters<PortId>::Out() = PortRegisters<PortId>::Dir();
    }

    static void SetDirection(Pins pin, PinIO io)
    {
        BitFlag::Set(PortRegisters<PortId>::Dir(), (uint8_t)pin, io);
    }

    static void SetDirection(PinIO io7, PinIO io6, PinIO io5, PinIO io4, PinIO io3, PinIO io2, PinIO io1, PinIO io0)
    {
        PortRegisters<PortId>::Dir() = io7 << 7 | io6 << 6 | io5 << 5 | io4 << 4 | io3 << 3 | io2 << 2 | io1 << 1 | io0;
    }

    static void SetDirection(uint8_t allPinsIO)
    {
        PortRegisters<PortId>::Dir() = allPinsIO;
    }

    static void Write(Pins pin, bool value)
    {
        BitFlag::Set(PortRegisters<PortId>::Out(), (uint8_t)pin, value);
    }

    static bool Read(Pins pin)
    {
        return BitFlag::IsTrue(PortRegisters<PortId>::In(), (uint8_t)pin);
    }

    static uint8_t ReadAll()
    {
        // set all pins to input to read their state
        PortRegisters<PortId>::Dir() = 0x00;
        return PortRegisters<PortId>::In();
    }

    static void WriteAll(uint8_t value)
    {
        // set all pins to output to write the value
        PortRegisters<PortId>::Dir() = 0xFF;
        PortRegisters<PortId>::Out() = value;
    }

    static void EnablePortInterrupt(bool enable = true)
    {
        const uint8_t portFlag = (((uint8_t)PortId >> 3) - 1);
        if (enable)
            PCIFR |= portFlag;
        else
            PCICR & !portFlag;
    }

    static bool IsPortInterruptEnabled()
    {
        const uint8_t portFlag = (((uint8_t)PortId >> 3) - 1);
        return PCIFR & portFlag;
    }

private:
    Port() {}
};

// ----------------------------------------------------------------------------

template <const PortPins PortPinId>
class PortPin
{
#if defined(__AVR_ATmega328P__)
    static_assert(PortPinId != TO_PORTPIN(Ports::C, Pins::Pin7), "The ATmega328P does not have a PortC-Pin7 pin.");
#endif

#define PortId TO_PORT(PortPinId)
#define PinId TO_PIN(PortPinId)

public:
    // Enables the internal pull-up for inputs.
    // Returns false when pin is not an input.
    static bool EnablePullup(bool enable = true)
    {
        // weirdest syntax ever 'template'
        uint8_t mask = Bit<(uint8_t)PinId>::template getMask<uint8_t>();

        if ((PortRegisters<PortId>::Dir() & mask) == Input)
        {
            PortRegisters<PortId>::Out() |= mask;
            return true;
        }

        return false;
    }

    static void SetDirection(PinIO io)
    {
        Bit<(uint8_t)PinId>::Set(PortRegisters<PortId>::Dir(), io);
    }

    static void Write(bool value)
    {
        Bit<(uint8_t)PinId>::Set(PortRegisters<PortId>::Out(), value);
    }

    static bool Read()
    {
        return Bit<(uint8_t)PinId>::IsTrue(PortRegisters<PortId>::In());
    }

    static void Toggle()
    {
        Write(!Read());
    }

private:
    PortPin() {}
};

// ----------------------------------------------------------------------------

#if defined(__AVR_ATmega328P__)
/* ATmega238P
    PB0-PB7 = PCINT0-PCINT7
    PC0-PC6 = PCINT8-PCINT14
    PD0-PD7 = PCINT16-PCINT23
*/

/** Enables (or disables) an interrupt when the state of a Port-Pin changes.
 *  Use of this class also requires the use of the `ISR()` macro to implement the interrupt handler:
 *      PortB: `ISR(PCINT0_vect){}`
 *      PortC: `ISR(PCINT1_vect){}`
 *      PortD: `ISR(PCINT2_vect){}`
 *  The handler has to detect which pin of the specific port caused the interrupt
 *  if multiple pins have interrupt enabled.
 *  The handler also has to re-enable the Port interrupt after handling it.
 *  \tparam PortPinId is the Port and Pin the `Enable()` acts upon.
 */
template <const PortPins PortPinId>
class PortPinInterrupt
{
    static_assert(PortPinId != TO_PORTPIN(Ports::C, Pins::Pin7), "The ATmega328P does not have a PortC-Pin7 pin.");

#define PortId TO_PORT(PortPinId)
#define PinId TO_PIN(PortPinId)

public:
    static void Enable(bool enable = true)
    {
        if (enable)
        {
            PCMSK() |= (uint8_t)PinId;
            Port<PortId>::EnablePortInterrupt();
        }
        else
            PCMSK() &= ~(uint8_t)PinId;
        // we're not turning off port-interrupts
    }

    // TODO: is there a reg we can check?
    static bool HasFired()
    {
        // is PCIFR bit set for the correct port?
        // is PCMSK bit cleared for this pin?
        return false;
    }

private:
    PortPinInterrupt() {}

// get from port id to register memory address (0x68=>PCMSK0)
#define PCMSKAddress ((((uint8_t)PortId >> 3) - 1) + 0x68)

    static volatile uint8_t &PCMSK()
    {
        return _SFR_MEM8(PCMSKAddress);
    }
};
#endif //__AVR_ATmega328P__
