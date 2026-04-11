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

## Memory Management Unit  (MMU)

Normal Operation:

- Latch (6bit) for MMU-Bank
- Latch (6bit) for Task-Bank-maps
- Enable MMU RAM1 + RAM2

IO Operation (RD/WR):

- Decode IO address: A13, A14 and  A15
- Latch (6bit) for IO-MMU-Bank
- Latch (6bit) for IO-Task-Bank-maps
- Enable MMU RAM1 + RAM2
- WR-Enable MMU RAM1 + RAM2
- Data Direction (RD/WR) for buffers (MMU_RAM_DDIR)
- Data Enable for RAM1 or RAM2

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

## IO Decoder

IO address for:

- System IO - Data RD/WR and Status RD/Command WR
  - Data Direction (245)
  - Data Enabled (CE)
  - CMD bit

## Expansion Bus

- MEM-RD (MEMRQ+RD)
- MEM-WR (MEMRQ+WR)
- IO-IN (IOREQ+RD)
- IO-WR (IOREQ+WR)

- 20MHz clock on dedicated pin.
  - Output 10MHz (bus) clock
