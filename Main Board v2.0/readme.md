# Zalt 2

Version 2 of the Zalt homebrew Z80 computer.

## Z80 CPU

The main board runs a 20MHz Z80.

It contains a 512kB ROM and a 512kB RAM.

## Memory Management Unit

- `Page`: a block of 4k of  physical memory that can be freely mapped into the CPU address space.
- `Page Id` (0-8192) an identifier for a memory page from physical memory.
- `Page Index` (0-15) a location for each of the 16 (active) CPU memory pages.
- `Bank`: A collection of assigned `Page Id`s for all `Page Index`es. Only one bank is active at a time and it defines what physical memory pages are visible to the CPU.
- `Bank Id` (0-32): a stack of max 32 banks that are available to the program/task.
- `Map Id` (0-64): allows each task (as in multi-tasking) to have their private stack of (32) banks.

> The ratio between available Bank-Ids and Map-Ids can be changed later if needed.

### Memory Bank Mapping

The CPU memory address is mapped by the MMU to one of the memory pages in physical memory.
This takes the hi-nible of the CPU address to index the lookup table and produce the physical memory address.
Besides the memory address bits, the lookup table also outputs memory-protection bits for each page.

The values in the lookup table can be programmed, thus changing the pages pointed to in the specific page-index locations.

The OS forces one (or more) -at $000- page-index locations to be present in all memory banks.
This ensures that basic machinery for the OS is always accessible for each application memory configuration.

One 4k block of ROM contains only $FF's (RST38). RST38 is a trap instruction to (try to) catch run-away code.
This can be used to map into page-index's where no valid memory is to be configured.

Refer to the OS's [program loader](<./Source/CPU/Program Loader.md>) for more detail on how the 16 page-indexes are allocated.

## Expansion Bus

We are using a powered ISA backplane to make this a modular system.

> After some research I found the goal to keep the ISA bus ISA-compatible -that it would run original PC ISA-cards- to be a great burdon and compilcate the design unnecessary.

This expansion bus definition is different from the (PC) ISA definition, only the Power pins are kept the same.
