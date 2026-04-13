# MCU ATmega1284 Source Code

Toolchains: platform IO + VScode

Contains the source code for the System IO processor.

- USART (console) (2x)
- PS/2 Keyboard
- System Tick Timer
- Realtime Clock (RTC) timer
- Programmable Timer(s)
- Persistent Settings (EEPROM)
- SD-Card (SPI)

After a Command has been issued the relevant state-machine is activated.
Any state-machine that was active (but not finished?) is aborted/terminated.

## Status and Commands

| Bit | Status | Function | Description |
| -- | -- | -- | -- |
| 0 | Error | File | There is an error in the last file operation (per file handle) |
| 1 | Error | Console 1 | There was an error. |
| 2 | Output Empty | Console 1 | There is room to send another byte. |
| 3 | Input Full | Console 1 | The receieved byte can be retrieved. |
| 4 | Error | Console 2 | There was an error. |
| 5 | Output Empty | Console 2 | There is room to send another byte. |
| 6 | Input Full | Console 2 | The receieved byte can be retrieved. |
| 7 | Busy | System IO | System IO is doing work. |

| Byte | Command | Function | Description |
| -- | -- | -- | -- |
| 0000_0000 | - | - | - |
| 0000_1000 | FILE-OPEN-READ | File | |
| 0000_1001 | FILE-OPEN-WRITE | File | |
| 0000_1010 | FILE-READ | File | |
| 0000_1011 | FILE-WRITE | File | |
| 0000_1100 | FILE-CLOSE | File | |
| 0000_1101 | FILE-ERROR | File | |
| 0000_0001 | RTC-DATE | Realtime Clock | |
| 0000_0010 | RTC-TIME | Realtime Clock | |
| 0000_0100 | SETTING-READ | Configuration Settings | |
| 0000_0101 | SETTING-WRITE | Configuration Settings | |
| 0000_0110 | SETTING-ERROR | Configuration Settings | |
| 0001_000n | CONSOLE-READ-n | Console | |
| 0001_001n | CONSOLE-WRITE-n | Console | |
| 0001_010n | CONSOLE-ERROR-n | Console | |
| 0001_1000 | KEYBOARD-READ | Keyboard | |
| 0001_1001 | KEYBOARD-WRITE | Keyboard | |
| 0010_00nn | TIMER-SET-n | Programmable Timer-n | |

## Interrupt Levels

Iterrupts issued to the CPU:

| Level | Interrupt |
| -- | -- |
| 1 | System Tick Timer |
| 2 | Keyboard |
| 3 | Console 0 |
| 4 | Programmable Timer 0 |
| 5 | Console 1 |
| 6 | Programmable Timer 1 |
| 7 | Protocol Signal* |

> *) If a Procotol Signal is not needed, the interrupt will be assigned to Programmable Timer 2, which currently has no interrupt (polling-based).

Interrupts handled by the MCU (internally):

| Level | Interrupt |
| -- | -- |
| 0 | Hardware Reset |
| 1 | Protocol Data Exchange |
| 2 | Keyboard (pint) |
| 3 | Realtime Clock |
| 4 | System Tick Timer |
| 5 | Programmable Timer 0 |
| 6 | Programmable Timer 1 |
| 7 | SPI / SD-card |
| 8 | Console 0 |
| 9 | Configuration Setting Ready |
| 10 | Console 1 |
| 11 | Programmable Timer 2 |

The interrupt levels for handling internal interrupts in the MCU are fixed by the MCU.

## System Tick Timer

Fixed interval timer tick interrupts for the os to act upon.

- INT: every tick (100ms?)

> Implemented using Timer0 (interrupt) of the MCU.

## Realtime Clock

- CMD: RTC-DATE
  - RD: year (?)
  - RD: month (1-12)
  - RD: day (1-31)

- CMD: RTC-TIME
  - RD: hour (0-23)
  - RD: minute (0-59)
  - RD: second (0-59)

> Implemented using Timer2 (and the external 32.768kHz crystal) of the MCU.

## Configuration Settings

- CMD: SETTING-8
  - WR: address (0-255)
    - RD: value (slow)
    - WR: value (0-255)

- CMD: SETTING-16
  - WR: address (0-255)
    - RD: value LSB (slow)
    - RD: value MSB (slow)
    - WR: value LSB (0-255)
    - WR: value MSB (0-255)

> Implemented using the on-board EEPROM of the MCU.

## Console

- CMD: CONSOLE-n (n:0-1)
  - WR: value (0-255) - output
  - (or) RD: value (0-255) - input, response to INT
- STAT: OutputBufferEmpty, InputBufferFull
- INT: receive input

- CMD: CONSOLE-n-ERROR (n:0-1)
  - RD: error value

> Implemented off the USART0/1 (interrupts) of the MCU.

## PS2 Keyboard

- CMD: KEYBOARD (key-table values)
  - RD: LSB
  - RD: MSB
  - WR: LEDs
- INT: receive input

> Implemented off the Pin Interrupt of the MCU.

## Programmable Timers

- CMD: TIMER-n (n:0-1)
  - WR: interval (0=off)
- INT every tick (different prios)

> Implemented using Timer1 and Timer 3 (interrupts) of the MCU.

## SD-Card Files

- CMD: FILE-OPEN | mode (bit0: 0-read/1=write)
  - WR: file name (one char at a time) + terminating /0.
  - RD: file handle (CPU will wait till MCU is ready) (negative are error values)

- CMD: FILE-READ
  - WR: file-handle
  - INT: file block ready
  - RD: read file handle
  - RD: block length (0=EOF)
  - RD: block data per byte (till block length)

- CMD: FILE-WRITE
  - WR: file handle
  - WR: block length
  - WR: block data per byte (till block length)

- CMD: FILE-CLOSE
  - WR: file handle

- CMD: FILE-ERROR
  - WR: file handle
  - RD: error value

> Implemented using the SPI serial interface (interrupt) of the MCU.

## Data Exchange

The Read and Write data exchange (either data or command/status) have to be handled by the MCU.

The CPLD prepares the Data-Direction signal and the Command/Status bit before activating the Data-Enable signal (active low).

The Data-Enable signal will interrupt the MCU to allow it to read or write the data to/from the CPU data bus.

If the Command/Status bit is active, the MCU will either return the status byte -readilly available in memory- or store the requested command in memory and initialize the corresponding state-machine - clearing out any state that might be left there.

> State-machines that have not finished their state transitions -and required more IO with the CPU- will be aborted. If a state-machine just needs to finish it's background tasks, it is kept alive an gets a slice of the main loop (cooperative).

After the state-machine is initialized, the interrupt service handler is exited.

The main loop will perform the actions advance the state-machine.
The state-machine might signal an interrupt to the CPU (handled by the CPLD) as one of it's steps.

When a Data-Read is received  (another interrupt) the active state-machine is requested to yield a value.
If this value is not available yet (because the CPU is too fast) a pending or error condition has to be generated.

> Currently there is no way to distinguish a read data value from an error value:

- After a read, the corresponding error status or busy flag could be checked. This would double the data transfer.
- The CMD-protocol should be designed such, that there is room in the data-space returned from reads, to indicate errors (pending).

The state-machine can buffer data that will be read by multiple data-read operations.
If there a lot of time between isueing the command and being able to execute the first read, an interrupt should be used to signal completion of an asynchronous operation (the state-machine performed).
We have 7 interrupts in total.
Related signals could share interrupts and the client code on the CPU has to poll to know what operation completed.

Interrupt handling must be a short as possible in order not to frustrate other interrupts (data-exchange iterrupt is highest prio).
Especialy the system-tick timer has highest prio in order to have a stable tick pulse.
