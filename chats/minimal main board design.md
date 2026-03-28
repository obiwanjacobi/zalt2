User: For the new Main Board (v2.0 in Under Construction) I am thinking of including the CPU + Clock, MMU, RAM, ROM, CPLD (logic) and Extension Bus. 
If I can fit it, I also want a serial (TTL) port for a remote console. Any tips on how to implement this with very few components? (will use a USB-TLL adapter to connect to PC)

GitHub Copilot: Read [](file:///c%3A/My/MyProjects/Zalt/Under%20Construction/Main%20Board%20v2.0)

Read [](file:///c%3A/My/MyProjects/Zalt/Design/Additional%20Documents.md)

Read [](file:///c%3A/My/MyProjects/Zalt/Source/SystemController)

Read [](file:///c%3A/My/MyProjects/Zalt/Under%20Construction/System%20Controller%20v0.1)

Given that your board already has a **CPLD**, the most component-efficient approach by far is implementing a soft UART inside it. Here's a breakdown:

---

## Serial Port Options (fewest components first)

### Option 1: Soft UART in the CPLD (0 extra ICs)
Since you already have an EPM240 on the board with headroom in macrocells:

- Implement an 8N1 UART core in VHDL — TX + RX shift registers, a baud rate divider, and two I/O-mapped registers (data + status)
- **Components added: just a 3-pin header** (TX, RX, GND)
- Baud clock derived from the existing system clock via a divider in the CPLD
- The CPLD already handles I/O decoding, so no extra address decode logic needed
- Maps cleanly to Z80 `IN`/`OUT` instructions via `/IORQ`

This is the cleanest option. A minimal 8N1 UART at 115200 baud fits comfortably in a small fraction of the EPM240's macrocells.

### Option 2: TL16C550A / SC16C550 (1 extra IC)
If you prefer a proven, off-the-shelf UART with a 16-byte FIFO:

- **Single chip** (available in SOIC-28, saves PCB space vs DIP)
- 16-byte TX/RX FIFOs — helpful since the Z80 can't always service interrupts immediately
- Needs: D0–D7, A0–A2, `/CS` (from CPLD), `/RD`, `/WR`, `INT` (optional), and a **baud rate clock**
- **Baud rate clock**: The tricky part — it needs ×16 the baud rate (e.g. 1.8432 MHz for 115200). You can either add a small oscillator can, or generate it from the CPLD if your system clock divides cleanly

### Option 3: Bit-bang via a latch (minimal, CPU-intensive)
- Add one output bit (TX) and one input bit (RX) to an existing port/latch — if you have spare bits anywhere
- No extra chips if spare I/O exists in the CPLD
- CPU polling at tight timings → not great for CP/M, but workable for simple debug

---

## Recommendation

**Go with Option 1 — soft UART in the CPLD.**

For a CP/M console port, you need:
- A **data register** (I/O port, e.g. `$00`) — read/write
- A **status register** (I/O port, e.g. `$01`) — TX ready + RX data available flags
- TX and RX pins routed to a 3-pin header

The BIOS serial routines become simple `IN`/`OUT` calls. The CPLD's baud divider just counts system clock cycles — e.g. if your system clock is 10 MHz, divide by 87 for ~115200 baud (×16 oversampling = divide by ~1389 from system clock, or divide by 87 from 1.6× oversampled clock).

The only BOM addition is a **2×3 or 1×3 pin header** — essentially free in cost and space.

---

## Wiring to USB-TTL Adapter

```
Board Header    USB-TTL Adapter
GND     ------> GND
TX      ------> RXD
RX      <------ TXD
```
No level shifters needed since both sides are 3.3V/5V TTL. Just confirm your USB-TTL adapter voltage matches.

User: Can you give a VHDL example of how to implement it in the CPLD?

GitHub Copilot: Read [](file:///c%3A/My/MyProjects/Zalt/Decoder%20Board%20v1.0%20-%20locked/Quartus%2015)

Read [](file:///c%3A/My/MyProjects/Zalt/Under%20Construction/System%20Controller%20v0.1/KiCad)

Read [](file:///c%3A/My/MyProjects/Zalt/Decoder%20Board%20v1.0%20-%20locked/Quartus%2015/SystemLogic.vhd#1-1), lines 1 to 60

Read [](file:///c%3A/My/MyProjects/Zalt/Decoder%20Board%20v1.0%20-%20locked/Quartus%2015/MemoryController.vhd#1-1), lines 1 to 80

Good — I have their style from the existing VHDL (20 MHz clock, `n_` prefix for active-low, `ieee.numeric_std`, Z80 bus signals). 

Read [](file:///c%3A/My/MyProjects/Zalt/Decoder%20Board%20v1.0%20-%20locked/Quartus%2015/SystemLogic.vhd#60-60), lines 60 to 84

Now I have everything I need. Let me write a clean UART that matches their project style exactly. 

Created [](file:///c%3A/My/MyProjects/Zalt/Decoder%20Board%20v1.0%20-%20locked/Quartus%2015/UART.vhd)

I've saved the file to [Decoder Board v1.0 - locked/Quartus 15/UART.vhd](Decoder Board v1.0 - locked/Quartus 15/UART.vhd) as a reference alongside your existing CPLD VHDL — copy it into your new Main Board Quartus project when you set one up.

---

## How it works

### Baud rate (20 MHz clock)
$$\text{BAUD\_DIV} = \frac{20{,}000{,}000}{115200 \times 16} = 10.85 \rightarrow 11$$
$$\text{Actual} = \frac{20{,}000{,}000}{11 \times 16} = 113{,}636 \text{ bd} \quad (1.4\% \text{ error — within UART spec})$$

### TX: shift register packing
The 10-bit shift register is loaded as `stop(1) | data[7:0] | start(0)`. `tx_sr(0)` is the live TX output. Every 16 `baud_tick`s the register shifts right (inserts idle `'1'` at MSB), yielding: start → D0 → D1 → … → D7 → stop.

### RX: 16× oversampling
1. Idle → detects falling edge (start bit)
2. Counts 7 ticks to reach **bit centre**, verifies still low (false-start rejection)
3. Samples each of the 8 data bits and the stop bit at tick 15 (mid-bit)
4. Latches completed byte → `rx_ready = '1'`

### Instantiation in your top-level VHDL
```vhdl
uart0: entity work.UART(UART_rtl)
    generic map (CLK_FREQ_HZ  => 20_000_000,
                 BAUD_RATE    => 115_200,
                 IO_BASE_ADDR => 16#80#)
    port map (clk     => clk,
              n_reset => n_reset,
              n_ioreq => n_ioreq,
              n_rd    => n_rd,
              n_wr    => n_wr,
              a       => a(7 downto 0),
              d       => d,
              tx      => uart_tx,    -- route to 3-pin header
              rx      => uart_rx);
```

### EPM240 resource cost
A minimal 8N1 UART like this uses roughly **30–40 macrocells** out of 240 — well within budget alongside your existing decode logic.

### One thing to watch
There's no receive FIFO — if the Z80 doesn't poll fast enough a second incoming byte overwrites the first. At 115200 baud a character arrives every ~87 µs, which is comfortable for CP/M BIOS polling. If you need robustness add a 2-byte shadow buffer in the RX process.

Made changes.