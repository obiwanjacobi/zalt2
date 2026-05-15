#pragma once
#include <stdint.h>
#include <avr/io.h>
#include "UsartRegisters.h"
#include "Bit.h"

/** Indicates the result of a transmit operation.
 */
enum class UsartTransmitResult : uint8_t
{
    /** Successful. */
    Success,
    /** No data was received or still busy. */
    NotReady,
};

/** The UsartTransmit class implements the transmit functionality for a Usart port.
 *  \tparam UsartId indicates which Usart port this instance represents.
 */
template <const UsartIds UsartId>
class UsartTransmit
{
public:
    /** Enables (true) or disables (false) the transmitter.
     *  \param enable indicates the state.
     */
    void setEnable(bool enable = true)
    {
        Bit<TXEN0>::Set(UsartRegisters<UsartId>::getUCSRB(), enable);
    }

    /** Retrieves a value that indicates if the transmitter is enabled (true).
     *  \return Returns false when not enabled.
     */
    bool getEnable()
    {
        return Bit<TXEN0>::IsTrue(UsartRegisters<UsartId>::getUCSRB());
    }

    /** Retrieves a value indicating if transmission of data is complete.
     *  \return Returns true if the transmit operation is complete.
     */
    bool getIsComplete() const
    {
        return Bit<TXC0>::IsTrue(UsartRegisters<UsartId>::getUCSRA());
    }

    /** Blocks code execution until the transmit operation is complete.
     *  See also `getIsComplete()`.
     */
    void WaitIsComplete() const
    {
        while (!getIsComplete())
            ;
    }

    /** Retrieves a value indicating if another data byte is ready to be transmitted.
     *  This is different from the `getIsComplete()` in that transmission may still be taking place in the shift register,
     *  but the data register is empty and can accept new data.
     *  \return Returns true if the transmit operation can accept more data.
     */
    bool getAcceptData() const
    {
        return Bit<UDRE0>::IsTrue(UsartRegisters<UsartId>::getUCSRA());
    }

    /** Blocks code execution until the transmit operation can accept new data.
     *  See also `getAcceptData()`.
     */
    void WaitAcceptData() const
    {
        while (!getAcceptData())
            ;
    }

    /** Enables (true) or disables (false) the transmitter complete interrupt.
     *  When turning on interrupts you also have to implement the `ISR(USART[n]_TX_vect)` interrupt handler.
     *  This interrupt is most useful when implementing half-duplex communication where after transmitting,
     *  the receiver has to be switched on.
     *  \param enable indicates the state.
     */
    void setEnableIsCompleteInterrupt(bool enable = true)
    {
        Bit<TXCIE0>::Set(UsartRegisters<UsartId>::getUCSRB(), enable);
    }

    /** Retrieves a value that indicates if the transmitter complete interrupt is enabled (true).
     *  \return Returns false when not enabled.
     */
    bool getEnableIsCompleteInterrupt()
    {
        return Bit<TXCIE0>::IsTrue(UsartRegisters<UsartId>::getUCSRB());
    }

    /** Enables (true) or disables (false) the transmitter accept data interrupt.
     *  When turning on interrupts you also have to implement the `ISR(USART[n]_UDRE_vect)` interrupt handler.
     *  \param enable indicates the state.
     */
    void setEnableAcceptDataInterrupt(bool enable = true)
    {
        Bit<UDRIE0>::Set(UsartRegisters<UsartId>::getUCSRB(), enable);
    }

    /** Retrieves a value that indicates if the transmitter accept data interrupt is enabled (true).
     *  \return Returns false when not enabled.
     */
    bool getEnableAcceptDataInterrupt()
    {
        return Bit<UDRIE0>::IsTrue(UsartRegisters<UsartId>::getUCSRB());
    }

    /** Blocks execution until all data has been transmitted.
     *  See also `WaitAcceptData()`
     */
    void Flush()
    {
        WaitAcceptData();
        // TODO: quicker way?
    }

    bool getCanWrite() const
    {
        return getEnable() && getAcceptData();
    }

    /** Blocks until the transmitter accepts data and write data to the data register.
     *  \return Always returns `Success`.
     */
    UsartTransmitResult Write(uint16_t data)
    {
        WaitAcceptData();
        WriteInternal(data);
        return UsartTransmitResult::Success;
    }

    /** Write the data to the data register when the transmitter accepts data.
     *  When the transmitter is not ready to accept data, false is returned and the outResult is set to `NotReady`.
     *  \param data is the data to send.
     *  \param outResult is set with the result of the transmit operation.
     *  \return Returns true when successful.
     */
    bool TryWrite(uint16_t data, UsartTransmitResult &outResult)
    {
        if (!getAcceptData())
        {
            outResult = UsartTransmitResult::NotReady;
            return false;
        }

        WriteInternal(data);
        outResult = UsartTransmitResult::Success;
        return true;
    }

    /** Retrieves the Usart port identifier.
     *  \return Returns the UsartId template parameter.
     */
    UsartIds getUsartId() const
    {
        return UsartId;
    }

    /** Closes the Usart transmitter by disabling interrupts
     *  and the transmitter itself.
     */
    void Close()
    {
        setEnableIsCompleteInterrupt(false);
        setEnableAcceptDataInterrupt(false);
        setEnable(false);
    }

protected:
    /** Writes the (lower bits) data to the data register without error checking.
     *  Takes the use of 9-data bits into account.
     *  \param data is the data to write.
     */
    void WriteInternal(uint16_t data)
    {
        if (getIs9DataBits())
        {
            Bit<TXB80>::Set(UsartRegisters<UsartId>::getUCSRB(), (data & 0x0100) > 0);
        }

        UsartRegisters<UsartId>::getUDR() = (uint8_t)(data & 0xFF);
    }

    /** Indicates if 9-data bits is active.
     *  \return Returns true if 9-data bits are used.
     */
    static bool getIs9DataBits()
    {
        return Bit<UCSZ02>::IsTrue(UsartRegisters<UsartId>::getUCSRB());
    }
};