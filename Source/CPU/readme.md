# Z80 CPU Source Code

Toolchain: z88dk

## BIOS

Basic Input/Output System - contains hardware abstraction for main IO functions.

- Memory Management Unit - functions for all aspects of the MMU.
- Console IO - routines for serial communication
- Keyboard - low level keyboard scan routine and turning leds on.
- Persistent settings management.
- Realtime Clock functions (Date and Time)
- Storage interaction (TBD)

## OS

API / services for applications to run on the Zalt2 computer.

- Process managment (no threads, only process/task=program)
- Interrupt handling / vector management
- Streaming API
- Asynchronous communication
