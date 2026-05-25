# CPLD Xilinx XC95288XL

Toolchain: Xilinx ISE WebPack (14.7)

## Memory Decoder

Decode address for:

- ROM Enable
- RAM Enable

## Memory Protection Unit (MPU)

> triggers NMI for violation

- M1 & MEMRQ + RD => MP_EXE (implies MP_RD)
- MEMRQ + RD => MP_RD
- MEMRQ + WR => MP_WR

> MP_RD is a bit redundant. Read access can be assumed as default (and non-destructive). MP_EXE implies read access (M1 is only active at the start of an instruction, which can have additional read cycles). MP_RD could perhaps be renamed/reused for an OS-flag, marking a memory page as locked to applications. See Repurpose MP_RD chat.

Copy on write: mark a memory page as non-writable and keep separate flags in os-memory.
When the NMI triggers, lookup the additional flags and allocate an empty memory page.
Temporary put the two pages in the same memory bank and copy over the content.
Restore the original bank with the new mem-page copy instead of the old one.

Debug Breakpoint: add an address register to the CPLD and when the CPLD detects an execution (M1) at that address, it raises the NMI. The NMI-handler can then enters the debugger using the debug-console. That would mean a loooong interrupt.

Detect `HALT` stalls: when DI and HALT both active, the code will never run. Could count Refresh to detect HALT being active for too long.

> NMI: multiple uses arrise.

- NMI triggers on an actual violation. The program should be killed. Adjust the return address on the stack to handle what to do after that.
- NMI triggers but some function has to be performed and after that execution can continue.

### External DMA

There is a potential issue with external DMA of a smart device.

When a smart device takes over the CPU bus, the smart device has control of the (CPU) memory. The MMU (and MPU) are never turned off.
So the current memory bank the application was using last when making the call to initiate the DMA transfer, is still active.

To fix this we reserve (8) memory banks for the 8 smart devices (also 8 interrupts on the bus) and auto-select the memory bank for that specific smart device.
How does the CPLD know what smart-device is (going to be) active? The bus-req is coupled to the bus interupt index, it is basically a special interrupt.

The smart-device 'index' is used to activate that specific MMU-bank in a reserved/OS-dedicated MMU-map.
This has to be done by the CPLD when the bus is requested.
Select the MMU-map and the device-bank.
That way each device has their 'shared' memory mapped in a location suitable for that device. Other page-indexes can be mapped to a null-page to make them unusable.
The OS MMU-map (Task 0) will reserve the last 8 memory banks for the 8 smart-devices that the CPLD will use.

Access to the MMU-IO registers (to change MMU configuration) is already blocked if not in supervisor mode - so a smart-device can not reconfigure the MMU to gain access to other memory.

## Memory Management Unit  (MMU)

> Physical Memory is the total memory attached to the hardware.
> Logical Memory is the memory addressed by the Z80 CPU (64k).

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

When the SRAMs are disabled, the state of the MA13-MA25 lines is determined by weak pull-up/down resistors that map the bootstrap ROM code (4k) into address space $0000 of the Z80.

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

---

## TODO

- [ ] detect RETI - to know when interrupt/and RST returns. Assume DI for RSTs also.
  - [ ] Enable `BINTEN` when RETI returns (from an interrupt).
- [ ] detect all RST variants (11xxx111).
- [x] detect INT by CPU int-ack (IORQ+M1)
- [ ] add supervisor FF. Set on RST or INT and cleared on RETI. Track nesting of INT in RST - requires 2x RETI. Can check MMU_MP_OS bit for transition from user to supervisor mode.
- [ ] when coming out of reset the supervisor bit must be on
- [ ] prohibit MMU IO when supervisor is not set.
- [ ] MMU_MP_OS bit (instead of MMU_MP_RD) that is set for os data and code. Fault if MMU_MP_OS is set and supervisor FF is not on during a read or write.
- [ ] Perform no other checks when MMU_MP_OS bit is on. The os mixes code and data in memory pages.

- [x] detect a bus-req interrupt from a smart device.
  - [ ] auto-select the OS-task (0) MMU-map.
  - [ ] select the memory bank for the device requesting the interrupt.

- [ ] BINTACK is not really used. Each BIRQn has its own ACK.
- [ ] MMU-enable needs to be active when data is being written or read using IO - even when the FF is off.
