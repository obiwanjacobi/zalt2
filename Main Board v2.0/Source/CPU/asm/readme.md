# BIOS

Basic IO System

Contains routines to initialize and access the primary IO devices.

## Conventions

### Registers

`BC`, `DE`, `HL` and `AF` are used as OS-arguments and return values, filled and received by the calling application. Assume (as caller) these registers are not preserved when the call returns (except return values of course).

`BC'`, `DE'`, `HL'` and `AF'` are used by OS and are not preserved.

`IX` and `IY` are not used by the OS at all and are reserved for C-lang application code.

## Page 0

Page zero is the first 4k memory page that will live in all banks (except device specific banks). The page0 contains the necessary data and routines for the OS to operate and interact with (as an application).

- RST entry points: all RST instructions are used for application code to enter the OS.
- IM2 vector table. All the interrupt vectors that are used by the CPLD (BusIO and SystemIO) are located in the first bytes.
- MMU routines: functions to reconfigure and switch memory banks.
- NMI handler: handles memory protection faults.
- Task scheduler: schedules tasks on the system-tick interrupt.
- OS Task: the anchor for switching to and from the OS task (memory bank).

> Note that the IM2 vector table is laid out in the same addresses as the RST and NMI handlers, invalidating some of the vectors.

IM2 vector table at `$0000` (I register = `$00`), even vectors only, sharing addresses with RST and NMI handlers.

| Address | Bytes | Content | Even IM2 Data Bus Values |
|:-------:|:-----:|---------|:------------------------:|
| $0000–$0003 | 4 | **RST $00** — `JP nnnn` + align | ⛔ $00, $02 |
| $0004–$0007 | 4 | IM2 vector data | ✅ $04, $06 |
| $0008–$000B | 4 | **RST $08** — `JP nnnn` + align | ⛔ $08, $0A |
| $000C–$000F | 4 | IM2 vector data | ✅ $0C, $0E |
| $0010–$0013 | 4 | **RST $10** — `JP nnnn` + align | ⛔ $10, $12 |
| $0014–$0017 | 4 | IM2 vector data | ✅ $14, $16 |
| $0018–$001B | 4 | **RST $18** — `JP nnnn` + align | ⛔ $18, $1A |
| $001C–$001F | 4 | IM2 vector data | ✅ $1C, $1E |
| $0020–$0023 | 4 | **RST $20** — `JP nnnn` + align | ⛔ $20, $22 |
| $0024–$0027 | 4 | IM2 vector data | ✅ $24, $26 |
| $0028–$002B | 4 | **RST $28** — `JP nnnn` + align | ⛔ $28, $2A |
| $002C–$002F | 4 | IM2 vector data | ✅ $2C, $2E |
| $0030–$0033 | 4 | **RST $30** — `JP nnnn` + align | ⛔ $30, $32 |
| $0034–$0037 | 4 | IM2 vector data | ✅ $34, $36 |
| $0038–$003B | 4 | **RST $38** — `JP nnnn` + align | ⛔ $38, $3A |
| $003C–$003F | 4 | IM2 vector data | ✅ $3C, $3E |
| $0040–$004D | 14 | SYSINT 1–7 — IM2 vectors | ✅ $40, $42, $44, $46, $48, $4A, $4C |
| $004E–$005D | 16 | BIRQ0–7 — IM2 vectors | ✅ $4E, $50, $52, $54, $56, $58, $5A, $5C |
| $005E–$0065 | 8 | Free — IM2 vector data | ✅ $5E–$64 (4 vectors) |
| $0066–$0069 | 4 | **NMI** — `JP nnnn` + align | ⛔ $66, $68 |
| $006A–$00FF | 150 | ⚠️ NOT INITIALIZED | ⛔ $6A–$FE (75 vectors) |

The `RST` instructions define the ABI of the OS and device drivers.
A function id follows the RST instruction indicating what to perform.
Any parameters are either passed in registers or put in a dedicated memory block.

| RST | Role | Notes |
| -- | -- | -- |
| $00 | Boot / warm reset | Cannot use it for anything else |
| $08 | OS kernel | Memory, MMU, alloc, tasks, console I/O, everything OS |
| $10 | Storage / file system | High-level functions |
| $18 | Video / graphics | High-level functions |
| $20 | Reserved | audio |
| $28 | Reserved | network / future |
| $30 | Reserved | debug / trap hook or future |
| $38 | Stray trap | All memory is filled with $FF (RST38) |

## OS Initialization

Initialize Memory:

- copy page0 from ROM (currenly executing) to RAM and put that memory page on index 0 (this tranfers execution instantly).
- layout the other OS-pages (code from ROM) in the MMU (64k max)
- initialize OS data-page (RAM) and init stack (OS-specific)

## Memory Management

- MMU operations: map page into address space / change bank configuration
- Allocating a memory page per task.
- Provide Allocators on claimed memory pages (per task).

## Debugging

There are several options for debugging in place.

| Mechanism | How triggered | Use case |
| -- | -- | -- |
| RST $30 | Developer patches a byte | Intentional breakpoint |
| CPLD breakpoint register | M1 at watched address → NMI | Non-invasive / ROM breakpoint |
| HALT → NMI | Any HALT opcode → CPLD → NMI | Crash / unhandled fault trap |

RST $30 is a single byte (0xF7), so it can replace any opcode byte in-place. The handler:

- Saves the full register set into a fixed debug save-area in page 0
- The saved PC (from the stack) points past RST $30 — subtract 1 to get the actual breakpoint address
- Enters a debug monitor loop on the debug console (you already have SYSINT5 / console 1 for this)
- Can inspect/modify the save-area (= registers), read/write any memory
Single-step: temporarily write RST $30 at the next PC, patch the original opcode back, RETI

CPLD Breakpoint register:

- Breakpoints in read-only memory (device ROM, BIOS)
- No need to modify running code
- One NMI handler checks a flag to distinguish "memory protection fault" (existing) from "hardware breakpoint hit"

## Task Switching

For handling interrupts and performing os-functions (RSTs) a light form of task-switching is required. The idea is that upon entering an ISR or RST, the OS switches to it's own private Task memory layout, including it's own stack.

If not already in OS-task:

- stash current (app) SP
- stash current MMU active Task/Bank
- switch to OS-task

For RSTs this requires bringing over the parameters (registers) that acompanied the RST call, which may introduce some additional complexity. If the OS-Task is already active, nothing happens and it is not switched back (to what?) after the ISR or RST is finished.

Just before the INT or RST returns (from page0):

- activate stashed Task/Bank
- reinstate the SP (clear var to indicate no task/bank to switch back to)

### RST - OS function

```z80asm
; os_page0.asm
    di
    jp os_rst_n

; os_rst_n - os_rst.asm
    exx
    ; TODO=> save registers BC' DE', and HL'
    ld bc, <function-table>
    jp os_rst_dispatch

; os_rst_dispatch
    ; get rst-id and adjust caller return address (uses HL' and E')
    ; save (push) all caller's registers (retrieve earlier: BC', DE' and HL')
    ; save caller mmu + SP in TCB
    
    ; switch to full os-task (mmu + SP)
    ; execute os-function (uses BC and E) - requires parameters!
    
    ; load current task mmu and SP
    ; restore (pop) all caller's registers
    ; return to caller
```

### INT - Timer Interrupt

```z80asm
; os_int.asm
    ; save (push) all caller's registers (retrieve earlier: BC, DE and HL)
    ; save caller mmu + SP in TCB

    ; switch to full os-task (mmu + SP)
    ; execute task-scheduler

    ; load current task mmu and SP
    ; restore (pop) all caller's registers
    ; return to caller (ei)
```
