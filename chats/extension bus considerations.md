User: what would be a good extension bus definition. The design is to be modular in that the main board only provides in the basic compute needs. I want to add storage, keyboard/mouse and display in separate modules. 
My previous design attempted to split memory-based extension and io-based extensions into two headers, but that is no requirement.
I am also interested in signals that I might not have yet but are very useful to have in a modular system.

GitHub Copilot: Let me look at the existing design to understand what you already have before making recommendations.   

Read [](file:///c%3A/My/MyProjects/Zalt/Todo.md)

Read [](file:///c%3A/My/MyProjects/Zalt/README.md)

Read [](file:///c%3A/My/MyProjects/Zalt/Design/Additional%20Documents.md)

Read [](file:///c%3A/My/MyProjects/Zalt/Design)

Read [](file:///c%3A/My/MyProjects/Zalt/Under%20Construction/Main%20Board%20v2.0)

Viewed image [](file:///c%3A/My/MyProjects/Zalt/Design/IO%20Bus.png)

Viewed image [](file:///c%3A/My/MyProjects/Zalt/Design/Diagrams.png)

Now let me look at the existing expansion bus schematic: 

Read [](file:///c%3A/My/MyProjects/Zalt/Under%20Construction/Main%20Board%20v2.0/ExpansionBus.kicad_sch)

The expansion bus schematic is empty — it's a new design. Let me check the existing CPU and Decoder board schematics for signal context.  

Searched for regex `IORQ|MREQ|BUSREQ|BUSACK|WAIT|INT|NMI|HALT|RFSH|M1|RD|WR|CLK|RESET` (`**/*.sch`), 60 results

Read [](file:///c%3A/My/MyProjects/Zalt/Under%20Construction/Main%20Board%20v2.0)

Searched for regex `IORQ|MREQ|BUSREQ|BUSACK|WAIT|INT|NMI|HALT|RFSH|M1|RD|WR|CLK|RESET|A0|A1|A15|D0|D7|MA` (`**/CPU Board v1.0 - locked/Kicad/Z80 CPU Board.sch`), 80 results

Searched for regex `IORQ|MREQ|BUSREQ|BUSACK|WAIT|INT|NMI|HALT|RFSH|M1|RD|WR|CLK|RESET|A0|A15|D0|D7|MA` (`**/Decoder Board v1.0 - locked/**/*.sch`), 60 results

Let me check the CPU board connector signals closely and the current Main Board v2.0 schematics:  

Searched for text `IORQ|IEI|IEO|RFSH|3.3|SPI|UART|SERIAL` (`**/CPU Board v1.0 - locked/Kicad/Z80 CPU Board.sch`), no results

Read [](file:///c%3A/My/MyProjects/Zalt/Under%20Construction/Main%20Board%20v2.0/CPU.kicad_sch#1-1), lines 1 to 120

Searched for text `IORQ|RFSH|IEI|IEO|net_name|label` (`**/Under Construction/Main Board v2.0/CPU.kicad_sch`), 53 results

Searched for text `IORQ|RFSH|IEI|IEO|WAIT|INT|NMI|BUSREQ|BUSACK|RESET|CLK|MA|SPI|UART|3.3` (`**/Under Construction/Main Board v2.0/Control Logic.kicad_sch`), 1 result

Now I have a thorough picture of the Zalt system. Let me compile a well-structured recommendation.

---

## Zalt Extension Bus Definition

Based on the signals in your Main Board v2.0 schematics and your three target modules (storage, keyboard/mouse, display), here is a recommended unified single-connector bus.

---

### Signal Groups

#### Power (10 pins)
| Signal | Pins | Notes |
|--------|------|-------|
| +5V    | 3    | Multiple for current capacity and decoupling |
| +3.3V  | 2    | Modern chips on modules (SD, FPGA, MCUs) need this |
| GND    | 5    | Generous returns are important for signal integrity |

---

#### Address Bus (24 pins)
| Signal | Pins | Notes |
|--------|------|-------|
| A0–A15    | 16 | Z80 logical address, valid during `~MREQ` and `~IORQ` |
| MA12–MA19 |  8 | MMU physical bank bits — combined with A0–A11 gives the full 20-bit physical address (1MB) |

**Why not just A0-A15?** Without MA12–MA19, a memory-mapped module can't know *which physical page* the CPU is accessing. Your display and storage modules will likely want memory-mapped windows, so these bits are essential for correct decode.

---

#### Data Bus (8 pins)
| Signal | Pins | Notes |
|--------|------|-------|
| D0–D7 | 8 | Bidirectional. Bus transceivers on each module are required. |

---

#### CPU Control (14 pins)
| Signal | Dir | Notes |
|--------|-----|-------|
| `~MREQ`  | out | Memory request |
| `~IORQ`  | out | I/O request — **absent from your v1.0 BusSpy, don't omit it again** |
| `~RD`    | out | Read strobe |
| `~WR`    | out | Write strobe |
| `~M1`    | out | Opcode fetch / interrupt-acknowledge cycle |
| `~RFSH`  | out | Refresh cycle — modules must NOT respond during this; also useful to detect "CPU is idle" |
| `~HALT`  | out | CPU halted, useful for a coprocessor/debugger module |
| `~WAIT`  | in  | Open-collector, wired-OR. Any module stretches the bus cycle. |
| `~INT`   | in  | Open-collector interrupt. Any module can request an interrupt. |
| `~NMI`   | in  | Non-maskable interrupt. Reserve for power-fail or watchdog only. |
| `~BUSRQ` | in  | DMA bus request. A DMA-capable storage module can use this. |
| `~BUSACK`| out | DMA bus acknowledge. |
| `~RESET` | out | Active-low system reset driven from main board. |
| `CLK`    | out | CPU clock (variable-frequency, divided). **See SYSCLK below.** |

---

#### Interrupt Daisy-Chain (2 pins)
| Signal | Dir | Notes |
|--------|-----|-------|
| `IEI`  | in  | Interrupt Enable In from previous module / main board |
| `IEO`  | out | Interrupt Enable Out to next module |

This is the Z80's native interrupt priority mechanism. On the connector, IEI comes in on one pin and IEO passes through the module to the next. The main board feeds `IEI` of the highest-priority slot from its own chain.  
For modules that don't participate in the chain, tie IEI→IEO with a wire.

---

#### Sideband Clock (1 pin)
| Signal | Notes |
|--------|-------|
| `SYSCLK` | A fixed-frequency crystal-derived clock (e.g., **3.6864 MHz**, 7.3728 MHz, or 20 MHz from the oscillator before the divider). Independent of the CPU's variable clock. Every module that needs accurate timing (UART baud rate, PS/2 timing, VGA pixel clock PLL reference) uses this instead of `CLK`. |

Your existing system already has `CLK20` (20 MHz oscillator) in the CPU schematic — this is a natural candidate.

---

#### Sideband Configuration Bus (4 pins)
| Signal | Notes |
|--------|-------|
| `CFG_SCK`  | SPI clock from PSoC5 system controller |
| `CFG_MOSI` | SPI data out from system controller |
| `CFG_MISO` | SPI data in to system controller |
| `~CFG_CS`  | Per-slot chip-select (routed uniquely to each slot from the main board) |

This allows the PSoC5 to **identify modules**, load configuration into FPGAs/CPLDs on modules, and initialize hardware out-of-band — before the Z80 even runs. It also opens the door to hot-plug detection (poll each slot's `~CFG_CS` at startup).  
Alternatively I²C (SDA + SCL = 2 pins) is simpler if you don't need speed.

---

#### Pre-decoded Slot Selects (optional, 4–8 pins)
| Signal | Notes |
|--------|-------|
| `~SLOT_IO0`..`~SLOT_IO3` | 4 decoded IO windows (e.g., ports 0x40-0x4F, 0x50-0x5F…), driven by the main board decoder |

This is optional but makes module design much simpler — the module just connects `~SLOT_IOx` directly to its chip enables without needing any decode logic. The main board CPLD/FPGA generates these.

---

### Total Pin Count

| Group | Pins |
|-------|------|
| Power (+5V, +3.3V, GND) | 10 |
| Address A0–A15 | 16 |
| Physical address MA12–MA19 | 8 |
| Data D0–D7 | 8 |
| CPU control signals | 14 |
| IEI/IEO daisy-chain | 2 |
| SYSCLK | 1 |
| SPI sideband | 4 |
| Decoded slot selects (optional) | 4 |
| **Total** | **67 (63 without slot selects)** |

A **2×40 (80-pin) 2.54mm box header** (IDC ribbon cable style, like RC2014 extended) is a comfortable fit — 67 used pins leaves 13 spare for future signals or mechanical keying.

---

### Signals Worth Adding That Are New to Your Design

| Signal | Reason |
|--------|--------|
| `~IORQ` | Not on your v1.0 BusSpy — it was presumably only on the Decoder Board. Put it on the expansion bus. |
| `~RFSH` | Lets modules distinguish genuine memory access from refresh cycles. Also lets a bus sniffer module see CPU idle time. |
| `+3.3V` | Your FPGA-based VDP board and anything SD/NAND based needs it. |
| `SYSCLK` | Fixed reference clock independent of CPU speed divider — essential for keyboard/mouse timing (PS/2 is timing-critical) and UART baud. |
| `IEI/IEO` | Native Z80 priority interrupt chaining; you otherwise have to build a priority encoder. |
| `~BUSRQ` on the bus | Enables a future DMA storage controller to take the bus while the CPU waits. Already exists in the CPU, just needs routing to the connector. |
| SPI config sideband | Lets PSoC5 enumerate and configure modules — extremely useful for a modular system. |
| MA12–MA19 | Without these, memory-mapped modules can't correctly decode their physical window. |

---

### Per-Module Usage Summary

| Module | Key signals used |
|--------|-----------------|
| **Storage** (CF, SD, SPI flash) | A0–A7, D0–D7, `~IORQ`, `~RD`, `~WR`, `~WAIT`, `~INT`, `~BUSRQ` (for DMA), SYSCLK |
| **Keyboard/Mouse** (PS/2 or UART) | `~IORQ`, A0–A3, D0–D7, `~RD`, `~WR`, `~INT`, IEI/IEO, SYSCLK (critical for PS/2 timing) |
| **Display** (memory-mapped VDP/VGA) | A0–A15, MA12–MA19, D0–D7, `~MREQ`, `~RD`, `~WR`, `~RFSH`, `~WAIT`, `~INT` (VSYNC), SYSCLK |

User: I see you're leaning on the old design. This design is going to be a bit different. But you made some good suggestions.
The new design has more MA-lines: would there be any reason not to expose all of them on the EB?

GitHub Copilot: Read [](file:///c%3A/My/MyProjects/Zalt/Under%20Construction/Main%20Board%20v2.0/MMU.kicad_sch#1-1), lines 1 to 80

Searched for regex `MA\d+|label|hierarchical_label` (`**/Under Construction/Main Board v2.0/MMU.kicad_sch`), 80 results

So the new MMU goes all the way to **MA28** — that's a 29-bit physical address space (512MB). The old design only had MA12–MA19.

No strong reason not to expose all of them. The trade-offs are minor:

**Arguments for exposing all MA0–MA28:**
- A module doing memory-mapped decode *must* have all the bits above its window size to ensure it doesn't falsely respond to the wrong physical addresses. Missing upper MA bits = incomplete decode = address aliasing.
- Future-proofing: a module that today needs 4MB might later be redesigned to need more.
- Consistency: the bus means one thing everywhere — "here is the current physical address."

**The one real nuance:**
MA0–MA11 are almost certainly just A0–A11 pass-through (the within-page offset). So on the expansion bus you technically have redundancy between A0–A11 and MA0–MA11. You have two options:
- **Expose both** — no ambiguity whatsoever, modules pick whichever they need
- **Expose only A0–A15 + MA12–MA28** — saves 12 pins since MA0–MA11 ≡ A0–A11, at the cost of a convention that modules must know about

The second option is cleaner if you're pin-budget conscious, but requires that the MMU *never* translates the lower 12 bits (i.e., the page size is always fixed at 4K). If your MMU design allows variable page sizes or full translation of lower bits, expose all MA lines and drop the assumption.

Given you're going to MA28, I'd suggest the **pragmatic middle ground**: expose **A0–A15** (CPU logical, needed for I/O decode) **+ MA12–MA28** (17 MMU bank bits), totalling 32 address signals on the bus. That covers 29-bit physical decode without the redundant overlap, as long as page granularity stays at 4K.

User: I was thinking of using some of the higher MA lines for memory protection. That way each mem-page can also indicate if you can read and/or write to the page. It would be a global flag not something fancy like a per "process" kinda thing.
I have not thought of how to enforce these RD&WR bits yet, but...

GitHub Copilot: This is a clean and practical idea. Essentially you'd be using the MMU's lookup table entries to carry page *attributes* alongside the physical address. A few thoughts on the design space:

### Where to put the bits

The MMU translates a logical page number to a physical page number. The table entry has spare high bits — repurposing MA26–MA27 (or MA27–MA28, whatever your physical RAM ceiling actually is) as `WR_PROT` and `RD_PROT` flags is a natural fit. The CPLD/FPGA that holds the table already sees the translated value, so it can act on those bits without any extra hardware.

Two bits gives you four states which is more than you need, but useful:

| WR_PROT | RD_PROT | Meaning |
|---------|---------|---------|
| 0 | 0 | Normal R/W |
| 0 | 1 | Write-only (unusual, maybe for blind DMA target) |
| 1 | 0 | Read-only (ROM image, OS kernel, constant data) |
| 1 | 1 | No-access (unmapped trap page) |

### Enforcement options

The CPLD/FPGA already sees `~MREQ`, `~RD`, `~WR`, and the flag bits simultaneously, so it can evaluate a violation combinatorially:

- **`~NMI`** — best option for a protection fault. Non-maskable, so the OS handler always runs. The handler can log the faulting address (which is still on the bus during the early clock cycles), then either recover or halt. Works well as a "segfault" equivalent.
- **`~WAIT` held low indefinitely** — freezes the bus. Simple to implement but unrecoverable without a reset. More useful during debug than in production.
- **`~INT`** — too soft; the Z80 can have interrupts disabled at the wrong moment.

NMI is the right default. You'd wire the protection logic output as: `NMI_ASSERT = (~MREQ & ~WR & WR_PROT) | (~MREQ & ~RD & ~M1 & RD_PROT)`.

Note the `~M1` exclusion on read-protect — you almost certainly want instruction fetch (`M1`) to still work on read-protected pages in the read-only case (ROM), but you can make this a design choice via a configuration bit.

### Impact on the expansion bus

This is the important consequence: **those flag bits are not address bits**. If you expose MA27:MA26 on the expansion bus as part of the physical address, a memory module would decode them as address lines and respond to the wrong locations.

You have two clean options:

1. **Don't expose the flag bits on the EB at all.** Modules just see the real physical address (MA12–MA25 or whatever your physical ceiling is). Protection is enforced on the main board before the bus cycle completes — by the time a module sees `~WR` asserted, the main board has already blocked it or let it through.

2. **Expose them as separate, explicitly-named signals** — e.g., `MEM_WR_EN` / `MEM_RD_EN` (active-high "you are allowed to respond"). A module that wants to participate in protection (e.g., a smart RAM module that enforces its own write-protect independently) can use them. For most modules you just ignore those pins.

Option 1 is simpler and keeps the bus clean. Option 2 is more powerful but adds responsibility to every module designer.

The key decision to nail down first: **what is your practical physical RAM ceiling?** That determines how many of the MA bits are genuinely address lines vs. available for attributes. If you're targeting e.g. 8MB of RAM, you only need MA12–MA22 (11 bits × 4KB = 8MB), leaving MA23–MA28 as six free attribute bits — plenty of room for R/W protection plus future use (cache-disable, DMA-visible, etc.).

User: Would it be possible to also include execute-protect? Like test if M1 is active when the exe_prot is active?

GitHub Copilot: Yes, and it's arguably the most useful of the three protection bits for a system like this. The Z80 makes it easy because `~M1` is a dedicated signal that's only asserted during opcode fetch cycles — there's no ambiguity.

### The three-bit protection model

| Bit | Flag | Trigger condition |
|-----|------|-------------------|
| WR_PROT | Write-protect | `~MREQ & ~WR` |
| RD_PROT | Read-protect | `~MREQ & ~RD & M1` (M1 high = not a fetch) |
| EX_PROT | Execute-protect | `~MREQ & ~RD & ~M1` |

This maps directly onto the classic **W^X** (write XOR execute) model. You can enforce combinations like:

| WR | RD | EX | Meaning |
|----|----|----|---------|
| 0  | 0  | 0  | Normal R/W/X (stack, scratch RAM) |
| 1  | 0  | 0  | Read-execute only (ROM, OS kernel code+data) |
| 0  | 0  | 1  | R/W data, not executable (heap, stack — prevents code injection) |
| 1  | 0  | 1  | Read-only data (constants, lookup tables) |
| 1  | 1  | 1  | No-access (unmapped trap) |

### One subtlety: the RFSH cycle

The Z80 reuses A0–A7 and asserts `~MREQ` during refresh cycles, but `~RD` and `~WR` are both inactive and `~M1` is high. Your protection logic needs to gate on `~RFSH` to avoid false triggers:

```
VIOLATION = ~RFSH & (
    (~MREQ & ~WR  & WR_PROT) |
    (~MREQ & ~RD  & M1  & RD_PROT) |
    (~MREQ & ~RD  & ~M1 & EX_PROT)
)
```

`~RFSH` being low means it *is* a refresh — so `~RFSH = 0` suppresses the whole expression.

### NMI timing consideration

One practical concern: the NMI needs to be asserted while the CPU can still act on it, but you don't want to fire it on a *legitimate* M1 cycle (the fetch of the NMI handler itself). You should latch the violation flag on the rising edge of `~M1` (or the leading edge of `~MREQ`) and clear it once `~NMI` has been acknowledged — the Z80's NMI acknowledge cycle is visible as `~M1 & ~MREQ & ~RD & ~RFSH` with no `~IORQ`, which your CPLD can detect to clear the latch.

### Impact on MA bit allocation

So now you need three attribute bits instead of two. If your physical RAM ceiling is 8MB that's MA12–MA22 as address, leaving MA23–MA28 as six free bits — three go to WR/RD/EX protection with three still spare for future use (cache-disable, DMA-visible, peripheral-mapped, etc.). Very comfortable.

User: I am not following the other uses of spare MA lines: cache disable, DMA-visible and peripheral mapped... please explain

GitHub Copilot: These are ideas borrowed from real MMU designs (like the 68030 or x86 page tables). Whether they make sense for Zalt depends on what you end up building. Here's each one explained in your context:

---

### Cache-Disable

Only relevant if you ever add a cache — a fast SRAM that sits between the Z80 and main RAM and transparently stores recently accessed data. The problem is that some memory regions **must not be cached** because their content changes without the CPU writing to them:
- Memory-mapped I/O registers (reading a UART status register twice must actually hit the hardware twice)
- A display framebuffer that's also written by a display controller

If you have such a cache on a module, it needs to know per-page whether caching is allowed. The flag travels with every memory access so the cache can decide "bypass me" in one cycle.

**Relevance to Zalt:** Low unless you build a cache module. But if you ever do, retrofitting this into the MMU table later is painful — reserving a bit now costs nothing.

---

### DMA-Visible

Imagine a storage or display module that has its own DMA controller. It needs to read or write main RAM directly (asserting `~BUSRQ`). The question becomes: *which pages is it allowed to touch?*

A `DMA_VISIBLE` flag in the page table means the OS can mark only specific pages as reachable by DMA. Any DMA access to a page without this flag triggers a violation (via `~NMI` or a DMA controller status bit). This prevents a buggy or malicious DMA transfer from scribbling over the OS kernel.

The enforcement logic is slightly different — it's the **main board** rather than the CPU that checks it, specifically when `~BUSACK` is active and a DMA master is driving the bus.

**Relevance to Zalt:** Moderate. You mentioned a storage module and DMA (`~BUSRQ`) as a goal. If that storage module does DMA (e.g. SD card block transfer directly to RAM), this flag gives you a guard rail.

---

### Peripheral-Mapped

This one diverges from the others. Instead of a protection flag it's a *routing* flag — it tells the address decoder "this page is not backed by RAM, it's a memory-mapped peripheral window."

Normally your decoder decides what responds to a given address based on hard-wired decode logic. With a `PERIPHERAL` flag in the page table, the MMU itself participates in routing: a set bit means "don't assert RAM chip-enable, assert peripheral-select instead." The practical effect is that **a peripheral's memory window is now relocatable in physical address space** — you move it by reprogramming the MMU table rather than cutting traces.

For example: your display module's framebuffer could live at physical page 0x1F0 or 0x3A0 — the OS decides at boot by writing the MMU table. This is how modern systems do memory-mapped I/O cleanly.

**Relevance to Zalt:** This is actually quite relevant given your modular design. The alternative — hard-decoded physical addresses per module — means each module must be built for a fixed address range, which gets messy when you have multiple modules. A `PERIPHERAL` flag shifts that flexibility into software.

---

### Summary

| Flag | Useful if you build... | Enforcement point |
|------|----------------------|-------------------|
| Cache-Disable | A cache module | Cache module checks it |
| DMA-Visible | A DMA-capable storage/display module | Main board DMA arbiter |
| Peripheral-Mapped | Multiple memory-mapped modules with flexible addressing | Main board address decoder |

None of these are urgent for a first pass. The point was just that with 6 spare bits above your physical address ceiling, you have room to grow into them without a hardware revision.

User: DMA: Yes I plan to add intelligent modules that use DMA to efficiently transfer data. But I would want that transfer to be restricted by the standard RD_PROT and WR_PROT. If its the CPU or the DMA controller doing the accessing does not make a difference - I think (currently). Can you think of a reason this may not work/cause problems?
Perihperal: I intent to use the  standard Z80 IO instructions. These are one (or two) cycles slower, but it should only be for reading/writing status/control registers etc.
If a module has a memory page mapped to something else, it is still memory for the rest of the system.

GitHub Copilot: ### DMA and protection — potential problems

**1. Who drives the address bus during DMA, and does the MMU still translate it?**

This is the core issue. When `~BUSACK` is active, the CPU floats its buses and a DMA master drives A0–A15. The MMU still sees those lines and will still generate MA0–MA28 from whatever is on A0–A15 — so the protection bits *do* get consulted, but only if:

- The DMA master uses **logical addresses** (from the CPU's address space / current page table)
- The MMU remains **active during DMA** (i.e., not bypassed by a separate `MMU_ENABLE` gated on `~BUSACK`)

If your smart modules drive physical addresses directly and bypass the MMU, protection is silently defeated. The bus design needs to be explicit: **DMA masters must use logical addresses and the MMU must remain active during `~BUSACK`**. This is a convention worth documenting in the bus spec.

**2. NMI cannot be serviced while `~BUSACK` is active**

The Z80 only samples `~NMI` between instructions, and it won't regain control until `~BUSREQ` is released by the DMA master. So if a DMA transfer violates protection:
- The NMI fires
- The CPU is still frozen on `~BUSACK`
- The violating transfer **continues to completion** before the CPU can run the NMI handler
- By then, damage (corrupt write, leaked read) is already done

You can mitigate this by having the protection logic also assert a **`~BUSREQ` override** — force-releasing the DMA master from the bus before the transfer byte completes, then letting the NMI fire. This requires a priority arbiter on `~BUSREQ`/`~BUSACK`. It's extra logic but makes enforcement atomic.

**3. Asymmetric protection needs**

Consider a video display module doing DMA reads from the framebuffer. You almost certainly want user code to be *unable* to read the framebuffer from the CPU (RD_PROT set), but the display module *must* read it. If RD_PROT applies equally to all DMA, your display breaks.

The cleanest solution is a **"system mode" flag** — one dedicated input signal on the main board (driven HIGH by the PSoC5 or a supervisor) that, when active, bypasses the protection check entirely. The display module asserts this line before starting its DMA. In effect: "I am a trusted device, not user code." This is roughly analogous to kernel mode vs. user mode.

---

### On I/O instructions

Good choice and no issues there. The one thing to be aware of: the Z80 has only 256 I/O ports (A0–A7 decoded with `~IORQ`), and some tools/software also decode A8–A15 to get 65536 effective ports. With multiple modules each needing a handful of control registers, **port address allocation** becomes a bus spec concern — each slot should have a reserved, non-overlapping port range, probably encoded via a small DIP switch or resistor strap on the module so the system doesn't need auto-discovery.

User: DMA-1: I was planning on having the MMU active at all times. DMA overrides the CPU not the MMU.
DMA-2: Good point. If there are some loopholes in the mechanism its okay. I would not mind giving DMA more responsibility in doing the right thing, compared to buggy software ran by the CPU. A pragmatic middle-ground would be nice. Have to think about it.
IO: There is a 16-bit IO instruction. IN/OUT (C). That puts the B reg on the MSB address bits. We need that to program the MMU lookup table as well, driving A13-A15.

GitHub Copilot: ### DMA-1: MMU always active

Clean design. The one remaining implication: your DMA master must **manage its own page context**. When the CPU hands over the bus, the MMU still has the CPU's current page table loaded. If the DMA master wants to access a physical location that isn't currently mapped into the logical space, it either needs to:
- Work only within already-mapped pages (simplest, OS pre-maps the transfer buffers), or
- Reprogram MMU entries before asserting `~BUSREQ` — which means having IO access to the MMU table itself, which it can't do while the CPU is running

The pre-mapping approach ("OS sets up the DMA buffer pages before handing off") is the pragmatic solution and is exactly how real DMA drivers work. Document it as a bus convention: *caller is responsible for ensuring target pages are mapped before initiating DMA*.

---

### DMA-2: Pragmatic trust level

Simplest middle-ground: **suppress the NMI on DMA violations, but still latch a status flag**. The DMA master finishes its work, releases `~BUSREQ`, the CPU resumes and can poll or be interrupted by a softer `~INT` to check the violation register. The OS can then decide what to do — log it, abort the operation, reset the module. No hardware priority arbiter needed, just a latch and an interrupt line.

---

### IO: 16-bit address space

Good catch, and this has a direct consequence for module design on the expansion bus.

`IN r,(C)` / `OUT (C),r` puts **B on A8–A15** and C on A0–A7. Since the MMU uses A13–A15 for its own register addressing, any module that only decodes A0–A7 will **silently respond** whenever those upper bits happen to match, including during unrelated MMU programming cycles. For example, if a module listens on port `0x40` and the OS does `OUT (C)` with B=`0x00` and C=`0x40` to program the MMU, the module gets an unintended write.

The fix is straightforward: **every module that uses IO must decode all 16 address bits**, or at minimum must decode A8–A15 as a "this byte is for me" qualifier. The DIP switch / address strap approach I mentioned earlier should set both the A0–A7 base port *and* a specific A8–A15 prefix, so each module owns a unique 16-bit IO address range. The strap for an 8-bit slice (e.g. 8 control registers) would look like:

```
Module responds when:  A15=0, A14=0, A13=1 (module select prefix)
                   AND A7-A3 = strapped value (subdevice)
                   AND A2-A0 = register index
```

This keeps the MMU's use of A13–A15 clearly separated from module IO, as long as the OS knows which prefix belongs to which device.

User: We could supply a 'LowAddress8_Active' (or similar) line on the bus decoded by the CPLD as a service to the modules - now not every module has to do the same work - assuming this will be a common case.

GitHub Copilot: Yes, great idea. This is exactly the kind of service decode that belongs on the main board — the CPLD already sees all 16 address bits and `~IORQ`, so it can generate this for free.

You could actually offer a small family of pre-decoded qualifiers rather than just one:

| Signal | Condition | Used by |
|--------|-----------|---------|
| `~IO_LO` | `~IORQ & ~(A8|A9|A10|A11|A12|A13|A14|A15)` | Modules using simple 8-bit `OUT (n)` only |
| `~IO_HI` | `~IORQ & (A8\|A9\|A10\|...)` i.e. B≠0 | Distinguishes 16-bit `OUT (C)` cycles |
| `~IO_SLOT_x` | Per-slot decoded select (the strapped prefix) | Replaces all module-local decode entirely |

The most powerful form is `~IO_SLOT_x` — if the CPLD generates one active-low IO select per slot (4–8 of them, each corresponding to a strapped A8–A15 prefix), then modules need zero address decode logic. They just wire `~IO_SLOT_x` straight to their register file's chip-enable. The register index comes from A0–A2 or A0–A3.

This is the same idea as the `~SLOT_IO_x` pre-decoded selects I suggested in the original bus proposal, but now it's clearer *why* it's needed: the 16-bit IO address space makes full onboard decode genuinely burdensome for a small module.

The tradeoff is that the number of slots is then fixed at design time by the number of CPLD output pins you dedicate to slot selects. 8 slots seems like a practical ceiling for a stackable board system of this kind.

User: I view these options as nice-to-have at this moment. It is good to think about them and document them but the have second place in the decision making process.
Higher on that list is interrupts. I am familiar with how Z80 family chips implement interrupt hierarchy/priority. But I was unsure how to expose the on the expansion bus.
Unless you see the bus similar to ISA-slots (your previous remarks suggest that) - while I see the expension bus as a set of signals shared by all modules - no dedicated signals.

GitHub Copilot: Your point changes the picture significantly for interrupts. The IEI/IEO daisy chain is fundamentally **point-to-point** — each module passes IEI→IEO to the next in sequence. That only works if modules are physically ordered and the connector routes them in series, which contradicts a shared-signal bus where every pin connects to every module simultaneously. So daisy chain is off the table in your model.

On a true shared bus, the natural interrupt mechanism is **wired-OR `~INT`**:

- Any module pulls `~INT` low (open-collector, so no conflict)
- CPU acknowledges with the `~IORQ & ~M1` cycle
- **Problem:** in Z80 Mode 2, exactly one device must put its vector byte on D0–D7 during that ack cycle. With multiple modules sharing the bus, all of them see the ack — you need to ensure only the highest-priority requester responds.

The clean solution for a shared bus is a small **interrupt controller on the main board**:

- Bus carries a few **open-collector request lines**: `~IREQ0`, `~IREQ1` (priority tiers, like PC IRQ lines)
- Modules pull the appropriate tier low when they need service
- The main board controller (your PSoC5, or a CPLD block) arbitrates, drives `~INT` to the CPU, and handles the Mode 2 vector response on behalf of the winning module
- Modules expose their vector via their IO status registers which the controller reads

This is essentially a software-configurable 8259 PIC equivalent, but minimal. Two `~IREQ` lines gives you two priority tiers with any number of modules sharing each tier, software-polling within a tier to identify the source. That's likely sufficient for storage, keyboard and display.

The key insight is: **priority arbitration belongs on the main board for a shared bus**, not distributed across modules.

User: Yes. I was thinking of doing a interrupt controller -  just not sure how exactly.
I was hoping to still be able to use IM2 and vectors but have not fleshed out the details.
If you have separate IRQ lines should you also have separate INT-ACK lines?
Each module/device can pick one set (IRQ+INTACK) and publish interrupts and wait for the ack to activate to put it's vector on the bus. Not sure how that should work in combination with the Z80 though...

GitHub Copilot: Good instinct on separate INTACK lines. Let me walk through how it would all fit together with IM2.

### How Z80 IM2 works (the relevant part)

When `~INT` is acknowledged, the Z80 produces a distinctive cycle: **`~IORQ` and `~M1` both active simultaneously**. During that cycle it reads one byte from D0–D7 — the interrupt vector low byte. Combined with the `I` register as the high byte, this forms a pointer into a 16-bit jump table. The critical constraint is: **exactly one device may drive D0–D7 during that cycle**.

---

### The design: N IRQ+INTACK pairs

```
Bus signals (shared, open-collector IRQ):

  ~IRQ0  ──── highest priority
  ~IRQ1
  ~IRQ2
  ~IRQ3  ──── lowest priority

  ~INTACK0 ──── driven by main board controller
  ~INTACK1
  ~INTACK2
  ~INTACK3
```

Each module straps (jumper/resistor) to one `~IRQn` / `~INTACKn` pair. The sequence then becomes:

1. Module pulls its `~IRQn` low (open-collector, wired-OR so multiple modules can share a line if needed)
2. Controller sees pending IRQ, asserts CPU `~INT`
3. CPU finishes current instruction, generates `~IORQ & ~M1`
4. Controller decodes that cycle, identifies highest pending priority, asserts `~INTACKn`
5. Module sees its `~INTACKn` → drives its **vector byte** onto D0–D7
6. Z80 latches the byte, forms the full address, jumps to the handler
7. Handler runs, eventually deasserts `~IRQn`
8. Controller deasserts `~INTACKn`, deasserts `~INT` if nothing else pending

---

### The `~WAIT` trick for vector response timing

The module needs to put its vector byte on the bus within the Z80's data setup time — potentially just a few nanoseconds. That's tight for a module that might be an MCU or FPGA with its own clock domain. The controller can relax this by asserting `~WAIT` at the very start of the ack cycle, waiting one or two clocks, *then* asserting `~INTACKn`, and releasing `~WAIT` once the module has had time to respond. The module sees INTACK, drives its vector, and the CPU reads it cleanly.

---

### Why separate INTACK per priority level

You asked whether this was necessary. The answer is yes, for one specific reason: **the module must know it won the arbitration** before it drives D0–D7. If you only had a single shared `~INTACK` line, every module with a pending IRQ would see the ack signal and all of them would try to drive the data bus simultaneously — bus fight. With `~INTACKn` per level, only the winning module's line goes active, so only it drives the vector. All others stay silent.

---

### Practical sizing

Four pairs (8 pins total) is comfortable for your three target modules with one spare. Six pairs covers future growth without a hardware revision. Beyond that it starts consuming connector space for diminishing returns.

User: how do you handle an incoming interrupt when one is already active?

GitHub Copilot: The Z80 actually handles the basic case for you automatically, but there are layers worth understanding.

### What the Z80 does natively

When the CPU acknowledges `~INT`, it **clears IFF1 and IFF2** (the interrupt flip-flops), disabling further interrupts for the duration of the handler. So a second `~INT` arriving while a handler runs is simply ignored until the handler explicitly re-enables interrupts with `EI`. The Z80 is inherently serialised — no nesting by default.

This means your controller can assert `~INT` for a new pending IRQ immediately, and nothing bad happens. The CPU will acknowledge it the next time interrupts are enabled.

---

### `RETI` — the handshake back to the controller

The Z80 provides `RETI` (opcode `ED 4D`) specifically as an "I am done" signal to interrupt hardware. It restores `IFF1` from `IFF2` and, crucially, generates a recognisable two-byte fetch on the bus that external hardware can decode. Your controller should watch M1 bus cycles for `ED` followed by `4D` and use that as the trigger to:

1. Mark the current IRQ level as no longer being serviced
2. Check if any IRQ lines are still pending
3. Re-assert `~INT` if so

This is exactly what Z80 peripheral chips (CTC, SIO, PIO) do in daisy chain mode. Your controller does the same job in software-equivalent logic.

Handlers **must** end with `RETI` not `RET` — this is a bus convention, not just a software convention. `RET` will return correctly but the controller never gets notified and will think that IRQ level is still busy.

---

### If you want priority preemption (nesting)

The handler deliberately does `EI` early, immediately after saving registers. Now higher-priority interrupts can preempt it. The controller needs to track a **current-serving priority level** and only assert `~INT` if a pending IRQ is strictly higher priority than what is currently running:

```
ASSERT_INT = any IRQn pending where n < current_serving_level
```

`RETI` detection pops the level back. This gives you a small hardware priority stack. Two or three levels deep is sufficient for practical use — a keyboard interrupt preempting a storage interrupt preempting idle, for example.

---

### Practical recommendation

| Approach | Complexity | When to use |
|----------|-----------|-------------|
| Flat, no preemption | Simple — just latch pending IRQs, EOI register | Fine for disk + keyboard + display all at same priority |
| Priority with `RETI` decode | Moderate — controller tracks current level | Needed if display VSYNC must preempt a slow storage handler |

For your three modules, flat is probably sufficient initially. The `RETI` decode can be added to the controller later without changing the bus definition at all.

User: Serialized int ack is fine. All in all it is quite an elaborate circuit.

GitHub Copilot: Yes, but most of that complexity concentrates in one place — the main board controller (CPLD or PSoC5). The bus itself stays simple: a handful of open-collector `~IRQn` lines and matching `~INTACKn` lines. Modules are straightforward: pull a line, wait for ack, drive a byte.

The elaborate part — prioritisation, `RETI` detection, `~WAIT` stretching, pending latch — is all controller-internal logic that you implement once and never touch again. Every module benefits from it without needing to know how it works.

That's actually the right place to put complexity in a modular system: **the bus is simple, the controller is smart**.