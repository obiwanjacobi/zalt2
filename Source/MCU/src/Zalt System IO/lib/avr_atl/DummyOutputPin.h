#pragma once
#include "Port.h"

/*
    Can be passed to a template that requires a pin that you don't want to use.
 */
template <const PortPins PortPinId>
class DummyOutputPin
{
public:
    DummyOutputPin() {}
    DummyOutputPin(bool initialValue) {}

    void Write(bool value) const {}

    void Toggle() const {}
    bool getValue() const
    {
        return false;
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
