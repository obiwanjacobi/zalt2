# Z80 CPU Source Code

Toolchain: z88dk

## BIOS

Basic Input/Output System - contains hardware abstraction.

- Memory Management Unit - functions for all aspects of the MMU.
- Console IO - routines for serial communication
- Keyboard - low level keyboard scan routine and turning leds on.
- Persistent settings management.
- Realtime Clock functions (Date and Time)
- Storage interaction (TBD)
- programmable timers

## OS

API / services for applications to run on the Zalt2 computer.

- System Init: memory scan/test
- Program loader (applications, modules)
- Process managment (no threads, only process/task=program)
- Memory protection routines (MMU/NMI)
- Interrupt handling / vector management
- Asynchronous communication
- Device Physical/Logical (linux like)
- Streaming API (async) Data/Meta

Program Loader:

- Relocatable code?
- Segmented application format (S-records?) (data section, code section, etc)

## Shell

- command line interface
- built-in commands (monitor like)
  - system utils
    - memory: read/write/fill/test
    - memory manager:control MMU
    - keyboard test
    - inspect settings
  - debug: setup debug console
  - expansion bus
    - address cards (TBD)
- start programs (dos like)
