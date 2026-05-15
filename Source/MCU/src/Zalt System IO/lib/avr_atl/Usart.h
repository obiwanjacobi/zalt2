#pragma once
#include <stdint.h>
#include <avr/io.h>
#include "UsartConfig.h"
#include "UsartTransmit.h"
#include "UsartReceive.h"

/** The Usart class is the basis for the Usart ports on the AVR MCU.
 *  \tparam: UsartId is the Usart port this class represents.
 *  \tparam: TransmitT is the class used for transmission (TX).
 *  By default it is the UsartTransmit template class but the UsartOutputStream class can also be used.
 *  \tparam: ReceiveT is the class used for reception (RX).
 *  By default it is the UsartReceive template class but the UsartInputStream class can also be used.
 */
template <const UsartIds UsartId,
          typename TransmitT = UsartTransmit<UsartId>,
          typename ReceiveT = UsartReceive<UsartId>>
class Usart
{
    // TODO: support other usart ids
    static_assert(UsartId == UsartIds::Usart0 || UsartId == UsartIds::Usart1, "Only Usart0 and Usart1 are supported");

public:
    /** Gets the UsartId this instance represents.
     *  Returns the UsartId template parameter.
     */
    UsartIds getUsartId() const
    {
        return UsartId;
    }

    /// \todo TODO: OpenSync

    /** Configures the Usart for asynchronous communication.
     *  The Usart is enabled in the Power Reduction Register.
     *  Receiver and/or Transmitter are not enabled. No interrupts are enabled.
     *  \param config is an instance of UsartConfig information used to open the device.
     *  \return Returns true when successful. Only accepts async config.
     */
    bool OpenAsync(const UsartConfig &config)
    {
        UsartModes mode = config.getMode();

        if (mode != UsartModes::Async &&
            mode != UsartModes::AsyncDoubleSpeed)
        {
            return false;
        }

        if (UsartId == UsartIds::Usart0)
            PowerReduction::Usart0(PowerState::On);
        else if (UsartId == UsartIds::Usart1)
            PowerReduction::Usart1(PowerState::On);

        UsartRegisters<UsartId>::getUBRR() = config.getUBRR();
        UsartRegisters<UsartId>::getUCSRA() = config.getUCSRA();
        UsartRegisters<UsartId>::getUCSRB() = config.getUCSRB();
        UsartRegisters<UsartId>::getUCSRC() = config.getUCSRC();
        return true;
    }

    /** Closes the Usart by closing the transmitter and receiver.
     *  Clears buffer, disables interrupts and disables the receiver and transmitter.
     *  Disables the Usart in the Power Reduction Register.
     */
    void Close()
    {
        Receive.Close();
        Transmit.Close();
        PowerReduction::Usart0(PowerState::Off);
    }

    /** The instance of the Transmit class.
     */
    TransmitT Transmit;

    /** The instance of the Receive class.
     */
    ReceiveT Receive;
};