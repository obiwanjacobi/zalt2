# BIOS

Basic IO System

Contains routines to initialize and access the primary IO devices.

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
