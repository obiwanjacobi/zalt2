User: The toolchain for the XC95288XL does not seem to be available anymore. It also does not run on newer windows versions.
Is there an alternative toolchain (I heard of yosys) or a different chip?
Could I use 2 smaller cpld chips to still cover all the needs (I counted I need about 120 io)

GitHub Copilot: Search complete: Find CPLD design files

Searched for regex `XC95288XL|XC9500|CPLD`, 46 results

Searched for files matching `**/*.pld`, 26 matches

Searched for files matching `**/*.jed`, 19 matches

Searched for files matching `**/*.vhd`, 10 matches

Searched for files matching `**/*.v`, 2 matches

Searched for files matching `**/*.ucf`, no matches

Searched for files matching `**/*.xdc`, no matches

Searched for files matching `**/*.README*`, no matches

Searched for files matching `**/Main Board v2.0/CPLD/**`, 1 match

Searched for files matching `**/*.md`, 22 matches

Searched for files matching `**/*.txt`, 19 matches

Read [](file:///c%3A/My/MyProjects/Zalt/Todo.md)

Read [](file:///c%3A/My/MyProjects/Zalt/Under%20Construction/Main%20Board%20v2.0/Kicad/Control%20Logic.kicad_sch#1-1), lines 1 to 120

Read [](file:///c%3A/My/MyProjects/Zalt/Under%20Construction/Main%20Board%20v2.0/CPLD/UART.vhd#1-1), lines 1 to 80

Search complete: Find CPLD source and design files

Searched for files matching `**/Under Construction/Main Board v2.0/CPLD/**`, 1 match

Searched for files matching `**/*.vhd`, 10 matches

Searched for files matching `**/*.v`, 2 matches

Searched for files matching `**/*.ucf`, no matches

Searched for files matching `**/*.xise`, no matches

Searched for files matching `**/*.xst`, no matches

Searched for files matching `**/*.prj`, no matches

Searched for files matching `**/*.lct`, no matches

Searched for files matching `**/*.lpf`, no matches

Looking at your project, you're using the **XC95288XL-TQ144** (117 user IOs, 288 macrocells), which requires Xilinx ISE — a tool that won't run on Windows 10/11 and that AMD/Xilinx has fully discontinued. You also already use Quartus in the Decoder Board v1.0.

Here's a structured overview of your options:

---

## Toolchain: Does Yosys work for XC9500XL?

Short answer: **not reliably.** There is an experimental project (`yosys-f4pga-xc9500xl`, part of the old SymbiFlow effort) but it is unmaintained and not production-ready. Yosys is excellent for FPGAs (iCE40, ECP5, Gowin), but the XC9500XL CPLD architecture is a dead end for open-source tooling.

---

## Single-chip replacement with a working toolchain

### Altera/Intel MAX V — 5M2210ZT144 ★ recommended
| Property | Value |
|---|---|
| User I/Os (TQFP-144) | **132** (covers your 120) |
| Macrocells | 2210 |
| Toolchain | **Quartus Prime Lite** — free, Windows 10/11 |
| Instant-on | Yes (EEPROM-based, like a CPLD) |
| Familiarity | You already use Altera EPM240 in the Decoder Board |

This is the cleanest drop-in path. Same TQFP-144 footprint, familiar toolchain, enough IOs.

### Lattice MachXO3LF-9400C-TQFP144
| Property | Value |
|---|---|
| User I/Os (TQFP-144) | **113** — just below your 120 |
| Toolchain | Lattice Diamond — free, Windows 10/11 |
| Instant-on | Yes (flash-based) |

Only works if your actual routed IO count can be trimmed to ≤113. If you need 120+, you'd have to move to a BGA package.

---

## Two smaller chips — does it make sense?

Yes, and you already have the parts in your KiCad library.

### 2× Altera EPM240T100C5 ★ already in your library
- 80 user IOs each → **160 IOs total**
- After sharing clk/reset/bus signals (~15 pins), you have well over 120 unique connections
- Same Quartus Prime Lite toolchain
- TQFP-100, straightforward to place on the board
- The main cost is splitting your VHDL into two top-level entities with a defined interface between them

Alternatively, **2× MAX II EPM570T144** (116 IOs each, TQFP-144) keeps things in the same footprint family but with more headroom.

---

## Summary recommendation

| Priority | Choice | Toolchain | IOs |
|---|---|---|---|
| 1st | MAX V 5M2210ZT144 (single chip) | Quartus Prime Lite | 132 |
| 2nd | 2× EPM240T100 (already in lib) | Quartus Prime Lite | 160 |
| 3rd | MachXO3-9400 TQFP-144 (single chip) | Lattice Diamond | 113* |

*Only if IO count can be reduced to ≤113.

The MAX V route keeps you on Quartus (which you already know from the Decoder Board), avoids a BGA package, and fits your ~120 IO requirement in a single TQFP-144 chip. Your existing VHDL should synthesize cleanly under Quartus Prime Lite since you're already using standard IEEE styles.

User: The EMP240 is not really 5V tollerant without clamping diodes and series Rs. I was hoping to get rid of those...

GitHub Copilot: Good point — the EPM240 (MAX II) is **not** 5V tolerant, and neither is the MAX V. That's your core constraint. Here's what actually has true 5V tolerance:

---

## 5V-tolerant CPLD options

### Lattice ispMACH 4000 — LC4256V / LC4256ZC (TQFP-144) ★ best fit
| Property | Value |
|---|---|
| User I/Os (TN144) | **116** |
| 5V tolerance | Yes — "V" / "ZC" suffix = 5V tolerant I/O |
| Toolchain | **ispLEVER Classic** (free, Windows 10/11, VHDL support) |
| Status | Still in production |
| Macrocells | 256 |

The only catch: 116 vs your ~120. Worth reviewing your schematic to see if any signals can be shared or eliminated — looking at the Decoder Board `SystemLogic.vhd`, the old design sits closer to 80 pins, so the new design's count may have room to trim.

### Altera MAX 7000AE — EPM7512AE-TQ144
| Property | Value |
|---|---|
| User I/Os (TQ144) | **120** — exact match |
| 5V tolerance | Yes — 5V tolerant inputs, 3.3V TTL-compatible outputs |
| Toolchain | **Quartus II 13.0sp1** (free, Windows 10/11) |
| Status | Discontinued but widely available from stock |
| Macrocells | 512 |

Covers 120 IOs with zero margin. Quartus II 13.0sp1 is the last version supporting MAX 7000AE, but it runs fine on Windows 10/11.

### Microchip ATF1508AS (5V native)
- Full 5V Vcc, no level shifting at all
- But limited to 83 IOs in TQFP-100 → needs 2 chips for 120 IO
- No good VHDL toolchain (WinCUPL only, like your BusSpy board)

---

## Summary

| Chip | IOs | 5V tolerant | Toolchain | Single chip |
|---|---|---|---|---|
| LC4256ZC-TN144 | 116 | ✓ | ispLEVER Classic | ✓ (if ≤116) |
| EPM7512AE-TQ144 | 120 | ✓ inputs | Quartus II 13.0sp1 | ✓ |
| 2× ATF1508AS-TQ100 | 83+83 | ✓ (5V native) | WinCUPL only | ✗ |

The **LC4256ZC** is the cleanest path if you can stay at ≤116 pins — it's still produced, no EoL risk, and ispLEVER Classic is a proper VHDL toolchain. If you must hit 120, the **EPM7512AE** is the safe choice, just note it's EOL stock.

User: what about 2x ATF1508AS ?

GitHub Copilot: ## 2× ATF1508AS — detailed assessment

### Hardware ✓ Good fit
| Property | Per chip | 2× total |
|---|---|---|
| User I/Os (TQFP-100) | 83 | **166** — comfortable headroom |
| Macrocells | 128 | 256 (vs 288 on XC95288XL) |
| Vcc | 5V native | No level shifting at all |
| Status | Still in production (Microchip) | No EOL risk |

Inter-chip signals will consume some pins (clock, reset, bus signals you'd share), but 166 − ~15 shared = ~150 unique IOs, well above your 120.

### Toolchain — actually good news
The "WinCUPL only" note from before was outdated. There is a working modern open-source toolchain:

- **[prjbureau](https://github.com/whitequark/prjbureau)** — reverse-engineered ATF15xx bitstream format (by whitequark)
- **Yosys** — synthesis, takes Verilog natively; with **ghdl-yosys-plugin** it also accepts VHDL
- **ATMISP** (Microchip free tool) or OpenOCD — JTAG programming
- All run on **Windows 10/11**

So your existing VHDL (like `UART.vhd`, `MemoryController.vhd`) can target ATF1508AS directly via `ghdl → yosys → prjbureau fitter`.

### Main downsides
1. **Design split required** — you need to partition your logic into two top-level entities. The bus signals (A0-A15, D0-D7, n_rd, n_wr, n_memreq, n_ioreq, clk, n_reset) will be connected to both chips in parallel on the PCB; only the decoded outputs differ.
2. **prjbureau maturity** — functional but less polished than Quartus/ISE. The fitter can be stubborn with tight fits.
3. **Two JTAG chains** to manage (or daisy-chained).

### Natural split for your design
Looking at your `SystemLogic.vhd`, a clean partition would be:

- **Chip 1**: Memory management (`MemoryController` + `MemoryDecoder`) — address/data bus heavy
- **Chip 2**: I/O control, UART, system control signals — fewer bus pins needed

This split minimizes inter-chip signals to just clock, reset, and the few control outputs that one chip needs from the other.

---

**Bottom line**: 2× ATF1508AS is a solid choice — 5V native, still produced, and the toolchain situation is much better than it used to be. The design split is extra work but manageable given your existing clean VHDL architecture.