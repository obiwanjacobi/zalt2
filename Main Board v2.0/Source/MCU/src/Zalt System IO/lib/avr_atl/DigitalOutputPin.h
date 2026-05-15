#pragma once
#include "Port.h"

/*
    Initializes a PortPin to output.
 */
template <const PortPins PortPinId>
class DigitalOutputPin
{
public:
    /*
        The ctor sets the Pin on the Port to Output.
     */
    DigitalOutputPin()
    {
        PortPin<PortPinId>::SetDirection(Output);
    }

    /*
        The ctor sets the Pin on the Port to Output and writes the initialValue.
     */
    DigitalOutputPin(bool initialValue)
    {
        PortPin<PortPinId>::SetDirection(Output);
        PortPin<PortPinId>::Write(initialValue);
    }

    /*
        Writes the value to the Port/Pin.
     */
    void Write(bool value) const
    {
        PortPin<PortPinId>::Write(value);
    }

    void Toggle() const
    {
        PortPin<PortPinId>::Toggle();
    }
    /*
        Returns the value of the Port/Pin.
     */
    bool getValue() const
    {
        return PortPin<PortPinId>::Read();
    }

    /*
        Returns the Port based on the template parameter.
     */
    Ports getPort() const
    {
        return TO_PORT(PortPinId);
    }

    /*
        Returns the Pin based on the template parameter.
     */
    Pins getPin() const
    {
        return TO_PIN(PortPinId);
    }

    /*
        Returns the PortPinID template parameter.
     */
    PortPins getPortPin() const
    {
        return PortPinId;
    }
};
