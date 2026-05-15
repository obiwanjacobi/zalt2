# Zalt 2

Version 2 of the Zalt homebrew Z80 computer.

## Memory Management Unit

- `Page`: a block of 4k of  physical memory that can be freely mapped into the CPU address space.
- `Page Id` (0-8192) an identifier for a memory page from physical memory.
- `Page Index` (0-7) a location for each of the 8 (active) CPU memory pages.
- `Bank`: A collection of assigned `Page Id`s for all `Page Index`es. Only one bank is active at a time and it defines what physical memory pages are visible to the CPU.
- `Bank Id` (0-64): a stack of max 64 banks that are available to the program/task.
- `Map Id` (0-64): allows each task (as in multi-tasking) to have their private stack of (64) banks.

### CPU Address Space

There are 16 pages of 4k in CPU memory.

| Idx | Start | End | Size |
| -- | -- | -- | -- |
| f | $F000 | $FFFF | 4k |
| e | $E000 | $EFFF | 4k |
| d | $D000 | $DFFF | 4k |
| c | $C000 | $CFFF | 4k |
| b | $B000 | $BFFF | 4k |
| a | $A000 | $AFFF | 4k |
| 9 | $9000 | $9FFF | 4k |
| 8 | $8000 | $8FFF | 4k |
| 7 | $7000 | $7FFF | 4k |
| 6 | $6000 | $6FFF | 4k |
| 5 | $5000 | $5FFF | 4k |
| 4 | $4000 | $4FFF | 4k |
| 3 | $3000 | $3FFF | 4k |
| 2 | $2000 | $2FFF | 4k |
| 1 | $1000 | $1FFF | 4k |
| 0 | $0000 | $0FFF | 4k |

The CPU memory address is mapped by the MMU to one of the memory pages in physical memory.

## Expansion Bus

We are using a powered ISA backplane to make this a modular system.

> After some research I found the goal to keep the ISA bus ISA-compatible -that it would run original PC ISA-cards- to be a great burdon and compilcate the design unnecessary.
