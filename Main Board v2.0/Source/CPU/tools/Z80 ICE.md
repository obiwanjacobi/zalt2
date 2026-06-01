# Z80 In-Circuit Emulator

- Wiki: https://github.com/hoglet67/AtomBusMon/wiki
- Getting Started: https://github.com/hoglet67/AtomBusMon/wiki/User-Manual---Getting-Started
- Commands: https://github.com/hoglet67/AtomBusMon/wiki/User-Manual---Command-Reference

We have the eepizza variant with the Z80 adapter board:
https://github.com/hoglet67/AtomBusMon/wiki/Z80-CPU-Adapter

## Serial Connection

Baudrate: 115200
Data: 8-bits
Parity: None
Stop bits: 1
Flow Control: None (Disable RTS/DTR)

## Buttons (Adapter)

    | Z80 |
----+-----+---- Z80 adapter board
O SW1         O SW2
--------------- eepizza

SW1 resets the Z80 core
SW2 resets the AVR core (running the debugger software) and the Z80 core

## Leds (Adapter)

LEDs are not fitted.

LED1 indicated a break point has been hit
LED2 monitors the state of the external trigger 0 input
LED3 monitors the state of the external trigger 1 input
