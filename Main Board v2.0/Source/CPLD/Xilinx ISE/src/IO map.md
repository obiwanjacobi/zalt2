# CPLD System IO Map

All CPLD ports require **A[7:0] = 0xFF**.  
This ensures a normal 8-bit `OUT (n),A` / `IN A,(n)` instruction can never
reach a CPLD register unless `n = 0xFF`, which is reserved for system use.

The Z80 `IN r,(C)` / `OUT (C),r` form is used for all CPLD access, with the
BC register pair forming the full 16-bit IO address.

---

## Latch registers — MemController

**Qualifier:** A[15:12] = `0x0`, A[7:0] = `0xFF`, A[11:8] = register select

| Port   | A[11:8] | Register         | Dir | Bits used | Description                              |
|--------|---------|------------------|-----|-----------|------------------------------------------|
| 0x00FF | 0       | Normal latch lo  | r/w | [7:0]     | MAP[7:0]  — active during CPU memory cycles |
| 0x01FF | 1       | Normal latch hi  | r/w | [2:0]     | MAP[10:8] — active during CPU memory cycles |
| 0x02FF | 2       | IO latch lo      | r/w | [7:0]     | MAP[7:0]  — active during SRAM programming  |
| 0x03FF | 3       | IO latch hi      | r/w | [2:0]     | MAP[10:8] — active during SRAM programming  |
| 0x05FF | 5       | RAM CE enable    | w/o | [0]       | `1` = enable both mapping RAMs, `0` = disable. Defaults to `0` on reset. |

Registers 0x08FF–0x0DFF (A[11:8] = 8..D) are **reserved / free**.

---

## MPU cause register — MemProtection

**Qualifier:** A[15:12] = `0x0`, A[7:0] = `0xFF`, A[11:8] = `0x4`

| Port   | A[11:8] | Register      | Dir | Description                              |
|--------|---------|---------------|-----|------------------------------------------|
| 0x04FF | 4       | Cause register | r/o | Latched at the moment the NMI fired. Read by the NMI handler to identify the violation. |

| Bit | Name      | Meaning                          |
|-----|-----------|----------------------------------|
| 0   | cause_exe | Execute-protection violation     |
| 1   | cause_rd  | Read-protection violation        |
| 2   | cause_wr  | Write-protection violation       |
| 7:3 | —         | Read as 0                        |

---

## MCU interface ports — SysBridge

**Qualifier:** A[15:12] = `0x0`, A[7:0] = `0xFF`, A[11:8] = register select

| Port   | A[11:8] | Register        | Dir | Description                                    |
|--------|---------|-----------------|-----|------------------------------------------------|
| 0x06FF | 6       | Command / Status | w/o | CPU → MCU: command byte. MCU samples when `SYSCMD=1`, `SYSDDIR=1`. |
| 0x06FF | 6       | Command / Status | r/o | MCU → CPU: status byte. MCU drives bus when `SYSCMD=1`, `SYSDDIR=0`. |
| 0x07FF | 7       | Data             | w/o | CPU → MCU: data byte. MCU samples when `SYSCMD=0`, `SYSDDIR=1`. |
| 0x07FF | 7       | Data             | r/o | MCU → CPU: data byte. MCU drives bus when `SYSCMD=0`, `SYSDDIR=0`. |

`SYSDEN_N` enables the D-bus ↔ MCU data buffer during either port cycle.  
`SYSDDIR` tracks `CPU_WR_N` combinationally and is valid for the full IO cycle.  
Wait states (default 3 × 50 ns = 150 ns) are inserted automatically on both ports
to give the MCU time to respond; the count is set by the `WAIT_CYCLES` generic in `SysBridge`.

---

## SRAM data ports — MemController

Used to read or write individual cells in the two mapping RAM chips.
The IO latch registers (0x02FF / 0x03FF) must be loaded with the target
cell address (MAP[10:4]) before accessing these ports.

**A[15:12]** carries the lowest 4 bits of the cell address (MAP[3:0]).
These lines are hardwired on the PCB directly to the SRAM address pins;
the CPLD does not decode A[15:12] for these ports.

**Qualifier:** A[7:0] = `0xFF`, A[11:8] = `E` or `F`

| Port  | A[11:8] | A[15:12] | Dir | Description                              |
|-------|---------|----------|-----|------------------------------------------|
| 0xXEFF | E      | MAP[3:0] | r/w | MMU RAM1 — low  byte of 16-bit mapping entry |
| 0xXFFF | F      | MAP[3:0] | r/w | MMU RAM2 — high byte of 16-bit mapping entry |
