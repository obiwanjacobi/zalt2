# Zalt 2

Version 2 of the Zalt homebrew Z80 computer.

## Memory Management Unit

- `Page`: a block of 8k of  physical memory that can be freely mapped into the CPU address space.
- `Page Id` (0-8192) an identifier for a memory page from physical memory.
- `Page Index` (0-7) a location for each of the 8 (active) CPU memory pages.
- `Bank`: A collection of assigned `Page Id`s for all `Page Index`es. Only one bank is active at a time and it defines what physical memory pages are visible to the CPU.
- `Bank Id` (0-64): a stack of max 64 banks that are available to the program/task.
- `Map Id` (0-64): allows each task (as in multi-tasking) to have their private stack of (64) banks.

### CPU Address Space

There are 8 pages of 8k in CPU memory.

| Idx | Start | End | Size |
| -- | -- | -- | -- |
| 7 | $E000 | $FFFF | 8k |
| 6 | $C000 | $DFFF | 8k |
| 5 | $A000 | $BFFF | 8k |
| 4 | $8000 | $9FFF | 8k |
| 3 | $6000 | $7FFF | 8k |
| 2 | $4000 | $5FFF | 8k |
| 1 | $2000 | $3FFF | 8k |
| 0 | $0000 | $1FFF | 8k |

The CPU memory address is mapped by the MMU to one of the memory pages in physical memory.

## Expansion Bus

We are using a powered ISA backplane to make this a modular system.

> After some research I found the goal to keep the ISA bus ISA-compatible -that it would run original PC ISA-cards- to be a great burdon and compilcate the design unnecessary.

