#pragma once
#include "Port.h"

/*
    Initializes a Pin on a Port to input.
 */
template <const PortPins PortPinId>
class DigitalInputPin
{
public:
    /*
        The ctor sets the Pin as Input.
     */
    DigitalInputPin()
    {
        PortPin<PortPinId>::SetDirection(Input);
    }

    /*
        Reads the value from the Pin on the Port.
     */
    bool Read()
    {
        return PortPin<PortPinId>::Read();
    }

    /*
        Enables (true) or disables (false) the internal pull-up resistor the AVR (MCU) has on digital input pins.
     */
    void EnableInternalPullup(bool enable = true)
    {
        PortPin<PortPinId>::EnablePullup(PortPinId, enable);
    }

    /*
        Returns the Port based on the template parameter.
     */
    uint8_t getPort() const
    {
        return TO_PORT(PortPinId);
    }

    /*
        Returns the Pin based on the template parameter.
     */
    uint8_t getPin() const
    {
        return TO_PIN(PortPinId);
    }

    /*
        Returns the PortPinId template parameter.
     */
    uint8_t getPortPin() const
    {
        return PortPinId;
    }
};
