# CPLD Xilinx XC95288XL

Toolchain: Xilinx ISE WebPack (14.7)

## Memory Decoder

Decode address for:

- ROM Enable
- RAM Enable

Memory Protection:

> triggers NMI for violation

- M1 & MEMRQ + RD => MP_EXE
- MEMRQ + RD => MP_RD
- MEMRQ + WR => MP_WR

Copy on write: mark a memory page as non-writable and keep separate flags in os-memory. When the NMI triggers, lookup the additional flags and allocate an empty memory page.
Temporary put the two pages in the same memory bank and copy over the content.
Restore the original bank with the new mem-page copy instead of the old one.

> NMI: two uses arrise.

- NMI triggers on an actual violation. The program should be killed. Adjust the return address on the stack to handle what to do after that.
- NMI triggers but some function has to be performed and after that execution can continue.

## Memory Management Unit  (MMU)

Normal Operation:

- Latch (6bit) for MMU-Bank
- Latch (6bit) for Task-Bank-maps
- Enable MMU RAM1 + RAM2

IO Operation (RD/WR):

- Decode IO address for writing MMU SRAMs.
- Latch (6bit) for IO-MMU-Bank
- Latch (6bit) for IO-Task-Bank-maps
- Enable MMU RAM1 + RAM2
- WR-Enable MMU RAM1 + RAM2
- Data Direction (RD/WR) for buffers (MMU_RAM_DDIR)
- Data Enable for RAM1 or RAM2

Startup sequence:

At startup/powerup the MMU SRAMs are unitialized (assume garbage).
The CPLD will not enable the SRAMs initially until a specific (IO) write is performed from the Z80 code, indicating initialization of the SRAMs is complete.

When the SRAMs are disabled, the state of the MA13-MA25 lines is determined by weak pull-up/down resistors that map the bootup ROM code into address space $0000 of the Z80.

When the Z80 ROM initialization code is writing values to the MMU SRAMs, they are enabled to receive the write (of course). When the write is done, the state of the SRAM CE line is set to the value of the initialization FlipFlop.

The initialization FlipFlop can be set/reset targeting an output to a specific IO address.

IO Addresses:

- Total of 6 IO addresses requires 3 bits
- Reuse high address bits: `$aaaX_1111_1111_1111`
- A13-A15 select the MMU page address (X=0)
- lower IO address nibbles are `$F` to differentiate from normal IO.

Individual IO ports:

- Startup Latch/MMU Enable (1-bit) `$1FFF`
- Current bank latch (6-bits) `$3FFF`
- Current task latch (6-bits) `$5FFF`

- Change bank latch (6-bits) `$7FFF`
- Change task latch (6-bits) `$9FFF`
- RD/WR memory page in latched bank `$0FFF`-`$EFFF` (uses A13-A15)

## Interrupt Controller

handles Interrupt priority and promotes to INT

In order of prio:

- System IO Interrupts
  - System Timer
  - Programmable Timer(s)
  - PS2 Keyboard
  - Console 1
  - Console 2
- System IO Interrupt Acknowledge

- Expansion Bus Interrupts
  - Interrupt request 1
  - Interrupt request 2
  - Interrupt request 3
  - Interrupt request 4
  - Interrupt request 5
  - Interrupt request 6
- Expansion Bus Interrupt Acknowledge

- Interrupt Enable
  - Scan for RETI instruction after interrupt was issued.

## System IO

- System IO - Data RD/WR and Status RD/Command WR
  - CMD bit
  - Data Direction (245)
  - Data Enabled (CE) (last to activate)
  - Cyclc-count clock (20MHz) to generate CPU wait-states (MCU is slower).

See also Interrupt Controller for System IO interrupts.

## Expansion Bus

- MEM-RD (MEMRQ+RD)
- MEM-WR (MEMRQ+WR)
- IO-IN (IOREQ+RD)
- IO-WR (IOREQ+WR)

- 20MHz clock on dedicated pin.
  - Output 10MHz (bus) clock
