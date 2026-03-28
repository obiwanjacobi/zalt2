User: I am toying with a new version of my diy z80 computer design. This is the (partial) kicad schematic for the MMU. 
The top 3 Z80 address lines (A13-A15) index two fast cache SRAMs that are programmed with the values for the upper memory address lines (MA13-MA2x). Are you able to read this and understand it? (just checking before asking more questions)

GitHub Copilot: Read [](file:///c%3A/My/MyProjects/Zalt/Under%20Construction/Main%20Board%20v2.0/MMU.kicad_sch#1-1), lines 1 to 100

Read [](file:///c%3A/My/MyProjects/Zalt/Under%20Construction/Main%20Board%20v2.0/MMU.kicad_sch#101-101), lines 101 to 300

Ran terminal command: Get-Content "c:\My\MyProjects\Zalt\Under Construction\Main Board v2.0\MMU.kicad_sch" | Measure-Object -Line

Ran terminal command: Get-Content "c:\My\MyProjects\Zalt\Under Construction\Main Board v2.0\MMU.kicad_sch" | Select-String -Pattern '(symbol \(lib_id|net_label|net_tie|global_label|hierarchical|wire|bus\b)' | Select-Object -First 80 | ForEach-Object { $_.Line.Trim() }

Ran terminal command: $lines = Get-Content "c:\My\MyProjects\Zalt\Under Construction\Main Board v2.0\MMU.kicad_sch"
# Find all symbol instances (placed components)
$inSymbol = $false
$depth = 0
$symbols = @()
for ($i = 0; $i -lt $lines.Count; $i++) {
    $line = $lines[$i].Trim()
    if ($line -match '^\(symbol \(lib_id') {
        $symbols += $line
    }
}
$symbols | Select-Object -First 60

Ran terminal command: Select-String -Path "c:\My\MyProjects\Zalt\Under Construction\Main Board v2.0\MMU.kicad_sch" -Pattern '\(lib_id' | ForEach-Object { $_.Line.Trim() } | Sort-Object -Unique

Ran terminal command: Select-String -Path "c:\My\MyProjects\Zalt\Under Construction\Main Board v2.0\MMU.kicad_sch" -Pattern '\(property "Reference"' | ForEach-Object { $_.Line.Trim() } | Where-Object { $_ -notmatch '"U"$|"#PWR"' } | Sort-Object -Unique

Ran terminal command: $content = Get-Content "c:\My\MyProjects\Zalt\Under Construction\Main Board v2.0\MMU.kicad_sch" -Raw
# Extract net labels
$labels = [regex]::Matches($content, '\(net_label\s*\(text\s*"([^"]+)"')
$labels | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique

Write-Host "---GLOBAL LABELS---"
$glabels = [regex]::Matches($content, '\(global_label\s*\(text\s*"([^"]+)"')
$glabels | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique

Ran terminal command: Select-String -Path "c:\My\MyProjects\Zalt\Under Construction\Main Board v2.0\MMU.kicad_sch" -Pattern 'net_label|global_label' | ForEach-Object { $_.Line.Trim() } | Select-Object -First 80

Ran terminal command: Select-String -Path "c:\My\MyProjects\Zalt\Under Construction\Main Board v2.0\MMU.kicad_sch" -Pattern 'label' | ForEach-Object { $_.Line.Trim() } | Select-Object -First 80

Ran terminal command: Select-String -Path "c:\My\MyProjects\Zalt\Under Construction\Main Board v2.0\MMU.kicad_sch" -Pattern '"Value" "U' | ForEach-Object { $_.Line.Trim() }

Read [](file:///c%3A/My/MyProjects/Zalt/Under%20Construction/Main%20Board%20v2.0/MMU.kicad_sch#2500-2500), lines 2500 to 2700

Let me look at the component placements section which comes after the lib_symbols: 

Ran terminal command: $lines = Get-Content "c:\My\MyProjects\Zalt\Under Construction\Main Board v2.0\MMU.kicad_sch"
# Find line numbers of key sections
for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match '\(symbol \(lib_id|"Reference" "U[2-9]|"Value" "(IS62|74HC|74HCT)') {
        Write-Host "$($i+1): $($lines[$i].Trim())"
    }
} | Select-Object -First 60

Ran terminal command: $f = "c:\My\MyProjects\Zalt\Under Construction\Main Board v2.0\MMU.kicad_sch"
Select-String -Path $f -Pattern '"Reference" "U[2-9]|"Value" "(IS62|74HC|74HCT)' | Select-Object LineNumber, Line | Format-Table -AutoSize

Searched for regex `"Reference" "U2|"Reference" "U3|"Reference" "U4|"Reference" "U5|"Reference" "U6|"Reference" "U7|lib_id "Memory_RAM|lib_id "74xx` (`Zalt` · `Under Construction/Main Board v2.0/MMU.kicad_sch`), 12 results

Read [](file:///c%3A/My/MyProjects/Zalt/Under%20Construction/Main%20Board%20v2.0/MMU.kicad_sch#5376-5376), lines 5376 to 5560

Read [](file:///c%3A/My/MyProjects/Zalt/Under%20Construction/Main%20Board%20v2.0/MMU.kicad_sch#5978-5978), lines 5978 to 6200

Now let me look at the net labels in context to understand the signal routing: 

Read [](file:///c%3A/My/MyProjects/Zalt/Under%20Construction/Main%20Board%20v2.0/MMU.kicad_sch#6440-6440), lines 6440 to 6700

Now let me look at the labels section to fully understand the signal flow: 

Read [](file:///c%3A/My/MyProjects/Zalt/Under%20Construction/Main%20Board%20v2.0/MMU.kicad_sch#2300-2300), lines 2300 to 2500

Searched for text `hierarchical_label` (`Zalt` · `Under Construction/Main Board v2.0/MMU.kicad_sch`), 1 result

Read [](file:///c%3A/My/MyProjects/Zalt/Under%20Construction/Main%20Board%20v2.0/MMU.kicad_sch#5302-5302), lines 5302 to 5380

Yes, I can read it clearly. Here's what I see:

**Components (6 ICs):**
- **U2, U5** — IS62C256AL (32K×8 SRAM) — the two lookup SRAMs
- **U3, U4** — 74HCT574 (octal D flip-flop/register) — latch the SRAM output
- **U6, U7** — 74HC245 (octal bus transceiver) — drive the translated address onto the MA bus

**Signal flow:**
1. The full Z80 address bus enters via hierarchical input `A` (A0–A15)
2. A13–A15 (3 bits → up to 8 segment entries) index U2 and U5, which act as a programmable lookup table
3. U3 and U4 latch the 8+8=16-bit SRAM output
4. U6 and U7 drive those 16 bits out as the upper physical address lines (MA13–MA28)
5. The lower 13 bits A0–A12 appear to pass through directly as MA0–MA12

**Net result:** A classic paged MMU. The Z80's 64KB address space is split into 8KB pages (2^13 offset), and the 3 upper bits select a "segment" whose physical base address is looked up in the SRAMs — giving a physical address space up to 2^29 = 512MB.

The IS62C256AL has 15 address lines, so beyond A13–A15, there are 12 more SRAM address inputs available — presumably for a process/context ID, which would make this a multi-context MMU.

Is that roughly what you have in mind?

User: You 've got it. The two latches are for separating read and write access. Is there any merrit in doing so, or is it an edge case that is ahrdly worth the trouble?

GitHub Copilot: This is a genuinely interesting design question. Let me think through it carefully.

**What split read/write mapping enables:**
The key use case is **ROM shadowing**. At boot, you map ROM into the read lookup (U2) and RAM into the write lookup (U5) at the same logical addresses. You copy ROM→RAM, then flip the read map to RAM too. Now you're running fully from RAM with no execution overhead, and the ROM is out of the picture. No software bank-switching stubs needed mid-copy.

A second use case is **copy-on-write** style tricks, where an OS-level write to a logical page silently redirects to a scratch page without the application knowing.

**The case against:**
- All standard Z80 software assumes reads and writes are symmetric. Split mapping is invisible to programs but a debugging nightmare if something goes wrong.
- CP/M, the most common Z80 OS, has no concept of it and won't use it.
- The ROM shadowing problem is solved equally well (and more predictably) by a single bit of bank-select logic — no MMU lookup needed for that specific case.
- If the two SRAMs are indexed by the same A13–A15 lines, the only way to get *different* mappings for read vs write is to program U2 and U5 with different contents. That's a software convention you now have to maintain.
- Two latches vs one latch adds a 74HCT574 and the associated control logic.

**Bottom line:** There's real merit, but it's a power-user feature that pays off only if the system software is explicitly designed around it. For a DIY Z80 that runs CP/M or homebrew code, it's almost certainly an edge case not worth the board space and timing complexity. A single latch with symmetric mapping would cover 99% of practical use cases.

Unless you have a specific OS design that deliberately exploits split mapping, I'd simplify to one latch/one SRAM per access.

User: No, I do not have any special use case for it. It was suggested to me by someone else, but it always sounded like a gimmic to me. 
One use case that I could see is that you put VRAM-writes in the same address space as ROM-reads - but I don't think I need this to realize that (it's a decoding problem, not an addressing problem)

GitHub Copilot: You're exactly right on both counts.

The VRAM example is a chip-select/decode problem: the Z80 asserts `~RD` or `~WR`, and your decoder uses that to gate which device responds — ROM on read, VRAM on write, same logical address. No address translation involved at all. A few gates or a GAL handles it trivially.

Split MMU mapping would only add value there if the VRAM were at a *different physical address* than the ROM, and you needed the MMU to silently redirect writes. But if you're the one designing the memory map, you just put them at the same physical address and let the decoder sort it out.

So — drop U5 (or whichever latch is for the write path) and simplify to a single SRAM + single latch. You get back board space, reduce power, and the design is easier to reason about and debug.

User: Agree. 
Obviously, these lookup-table SRAMs have to be fast. In my previous version I used a (single) GLT725608. Are there any other bottlenecks concerning timing for a 20MHz Z80? 

GitHub Copilot: Good instinct. For 20MHz (50ns clock), the timing budget is tight across the whole address translation chain. The bottlenecks in order of severity:

**1. Lookup SRAM access time (your biggest concern)**
The entire address translation has to complete before the downstream memory's address setup deadline. Your GLT725608 was fast (~15ns). The IS62C256AL in the current schematic is 25ns — that's already worrying before you add anything else on top.

**2. The latch clock — the trickiest problem**
The 74HCT574 is edge-triggered. You need to clock it *after* the lookup SRAM has settled, but *before* the main memory's address setup window closes. Generating that clock edge cleanly without a delay line or a GAL/CPLD is genuinely hard. A transparent latch (74HC373 or 74HC533) gated by /MREQ is arguably simpler — hold open while SRAM settles, close when /MREQ asserts to hold the value stable for the rest of the bus cycle.

**3. Transceiver propagation (U6/U7 — 74HC245)**
~7-8ns on top of everything else. Small but not free.

**4. The full chain adds up**
SRAM tAA (~15ns) + latch tCQ (~7ns) + transceiver tPD (~8ns) ≈ **~30ns of overhead** before the downstream memory even sees the physical address. At 20MHz without wait states, you've likely consumed half your entire memory access budget just in translation.

**Practical conclusion:** At 20MHz a wait state is almost unavoidable with this architecture. That actually relaxes most of the pain — with 1 wait state you get ~100ns total, and the design becomes buildable with standard fast SRAMs. Most 20MHz Z80 homebrew designs accept this.

User: The latch is set before memory access in the 8k page. So only the OE timing is at play here. The D-output of the SRAMs is not buffered so only the 15ns count (ignore the part I used on the schematic). Reevaluate please

GitHub Copilot: Good clarification — that changes the picture significantly.

If the latch is loaded on *page entry* (not every cycle), then within a page the latch Q outputs are already stable when any memory access begins. The translation overhead for in-page accesses is effectively **zero** — the main memory sees a fully valid address from T1 onset.

**What actually matters at 20MHz:**

**1. Main memory speed — now the dominant constraint**
With no translation overhead in-page, the full Z80 timing budget is available to the main memory. At 20MHz with a standard 2-wait no-wait read: address valid at T1, data required ~90ns later. That's achievable with 70–80ns SRAM without wait states.

**2. Page transition timing**
When A13-A15 change, the SRAM needs to settle (15ns) and the latch must be clocked *before* the first access in the new page. The question is how the latch clock is generated — if it's derived from address bus change detection, you need to guarantee it fires after 15ns but before /MREQ of the new cycle. That's the one real design risk here.

**3. Latch clock generation**
If you clock on /MREQ (which asserts 25ns after address — half a T1 at 20MHz), the SRAM has 25ns to settle before the latch captures, giving **10ns of margin** over the 15ns SRAM. That's clean and simple.

**4. U6/U7 transceivers — are they in the MA path?**
If the 74HC245s are between the latch and the main memory address bus, that's ~7ns in the critical path. If they're just for bus driving strength and are always-enabled, their propagation is absorbed into the already-stable latch output. Worth checking the schematic nets.

**Summary:** The design is sound. The main bottleneck is simply main memory speed, which is a pleasant problem — 55ns SRAM is plenty.

User: all the MMU control signals will be provided by a CPLD (or maybe even a small FPGA?) that will be on the board - not sure yet which one.
A mem-page transition is managed over IO that targets the latch that contains upper address bits. Only after that is done, the new mem-page configuration is active. Of course, care must be taken not to switch out the code that is currently running ;-)
The 245 bi-dir buffers are only there to program the lookup tables (I did not label the Data lines in the schematic yet).
Main memory is also very fast (15-20ns)- UM61512A

GitHub Copilot: That all makes perfect sense now. The full picture:

**The translation path is exactly:** Latch Q → MA[13..x] → UM61512A. Nothing else in-line.

**Timing is very comfortable:**
- UM61512A at 15-20ns with a 20MHz Z80's full read cycle budget (~115ns address valid window) — that's 5-6x headroom. No wait states needed.
- The lookup SRAM 15ns access only matters at page-switch time, and that's a software-controlled IO write, not a bus cycle race.

**The 245s make complete sense now** — write path to program the lookup SRAMs via the Z80 data bus, gated by the CPLD. Off the critical path entirely.

**On the CPLD vs FPGA question:**
- CPLD (MAX II, CoolRunner-II) is the natural choice here — deterministic combinatorial timing, no configuration bitstream, instant-on at power-up, and the logic is modest. Exactly what CPLDs were designed for.
- A small FPGA (iCE40, ECP5) buys you if you anticipate needing significant sequential logic (memory controllers, interrupt routing, bus arbitration). But you pay for it with startup time and external flash.
- A middle ground: use what you already have on the board — your workspace has Altera EPM240 files which is exactly the right class of device.

**One genuine design hazard worth calling out explicitly:** the page-switch IO write must be atomic with respect to the instruction stream. If an interrupt fires between the IO write and the first instruction in the new page, the ISR runs with the new mapping but returns to a now-unmapped code address. You probably need to mask interrupts around page switches in the OS, or have the CPLD enforce it.

User: I would like a little more IO on the cpld than the EMP240. With the extra high MA lines and possibly also connecting the Data bus, IO will be pretty much all be taken. 
I also am unsure on my level shifting solution (using diodes on the 3v3 side and a series R). Adding real level-shifter chips will add up quickly. Any suggestions?

GitHub Copilot: Two separate problems, and they have a single elegant solution:

**Use a 5V-native or 5V-tolerant CPLD — level shifting goes away entirely.**

Concrete options:

**Atmel/Microchip ATF1508AS**
- Genuine 5V CPLD, 128 macrocells, up to 100 I/O (TQFP100)
- Direct 5V in/out — no level shifting anywhere on the board
- WinCUPL compatible — you're already using WinCUPL for your BusSpy decoder, zero new toolchain
- Downside: 128 macrocells may still feel tight if you put complex logic in

**Xilinx XC95288XL**
- 3.3V core but **5V tolerant inputs** — solves the input direction entirely
- 288 macrocells, 192 I/O (TQFP144) — comfortably handles full address + data bus + control
- 3.3V outputs drive your 74HCT parts fine (HCT Vih = 2.0V) — you've already made the right choice using HCT for the latches
- Free toolchain (ISE WebPACK supports the XC9500XL family)
- Downside: outputs won't directly drive 74HC (non-T) parts, but you're already on HCT

**The XC95288XL is probably the sweet spot** — enough I/O to connect the full address bus, data bus, and all control signals in one device, 5V input tolerance eliminates the diode/resistor bodge, and the 3.3V→HCT output compatibility you've already accounted for. No level shifter chips needed at all.

User: Thanks I'll look into the XC95288XL. I think I already have a Xilinx programmer (IIRC)

GitHub Copilot: Good — the XC9500XL family programs via JTAG, so any Xilinx Platform Cable USB (or clone) will work. ISE WebPACK is the tool; version 14.7 is the last release and still freely downloadable from AMD/Xilinx. It runs on Windows and Linux, and 14.7 has native support for the full XC9500XL family including the 288.

One practical note: **get the TQFP144 package** rather than the smaller options — the extra I/O pins are exactly why you're choosing this part, and hand-soldering TQFP144 is still very doable with a fine tip and flux.

User: Yes, soldering is no problem. I hand soldered the EMP240 just fine ;-)

GitHub Copilot: Then the XC95288XL in TQFP144 will be no challenge at all. You're good to go.

User: Do you have any thoughts on the memory page size.
My previous design had 4k pages and I currently have set them at 8k.
4k felt a little small causing a bit of administration overhead, which I hope 8k will eleviate.

GitHub Copilot: 8K is a well-motivated choice. Some thoughts:

**Why 4K felt cramped**
With 4K pages and a 64KB address space you have 16 segments. Each segment needs a lookup entry, and every context switch / task swap has to reload all 16. The overhead is proportional to page count, not data size. CP/M especially — where the TPA needs to look contiguous — ends up with a lot of table juggling.

**8K is a natural fit for Z80**
- 8 segments in 64KB — simple, easy to reason about
- 8KB comfortably fits a typical CP/M BIOS + resident OS in one or two segments, leaving 6-7 fully available for user space
- 8KB is also the size of a standard 8K ROM, so ROM mapping aligns perfectly
- The lookup SRAM only needs 3 address bits (A13-A15), which you're already using

**Going larger — 16K?**
- Only 4 segments, very coarse
- Enough for simple single-tasking but you lose flexibility for anything more complex
- Probably too coarse if you ever want memory protection or multiple processes

**The sweet spot argument**
8K hits the crossover point where administration overhead is low *and* granularity is still fine enough for real OS work. 16K pages are what the Z80 MMU in the original Amstrad PCW used, and the limitations were noticeable. Most serious Z80 designs (ZPM, ZSDOS era) assumed 16 pages or 8 pages — the 8-page designs are consistently perceived as easier to program against.

Stick with 8K — it's the right call.

User: Do you think I need software facilities to link pages together. Guarentee that 'these blocks' will always stay in this sequence?
That  thought crossed my mind when working with 4k.

GitHub Copilot: Good instinct to think about it, but with 8K pages it's largely a non-problem — and here's why:

**The root cause at 4K**
With 4K pages, any non-trivial data structure, stack, or code segment risked spanning a page boundary. You then needed to either pad/align everything to 4K, or track which pages were "linked" and always swap them together. That's real OS overhead.

**Why 8K mostly eliminates it**
A Z80 stack rarely exceeds a few hundred bytes. String buffers, I/O buffers, typical data structures — comfortably within 8K. The cases where you genuinely need more than 8K of *logically contiguous* space are rare in Z80 code, and when they do occur (large file buffers, video RAM) they're typically handled by explicit segmented access anyway.

**The one real remaining case**
Code that crosses a page boundary — a subroutine where the call is in one 8K page and the body is in the next. The Z80 has no segment register for code, so logical address continuity *is* physical continuity within the 64KB space. As long as you (or your linker/assembler) lay out code so that page N and page N+1 in logical space map to adjacent physical pages when needed, it's fine. This is a **linker/loader concern**, not a runtime page-linking facility.

**What you actually need instead**
A simple physical page allocator that can hand out *a run of N contiguous physical pages* when asked. That's a few lines of bitmap search. No complex linking metadata, no runtime guarantees to maintain — just "give me 2 adjacent free pages" at load time.

So: no page-linking facility needed, but a contiguous-allocation hint in your memory allocator is worth the ten lines it takes to write.

User: Because of the 8-bit latch there are 256 map-configurations (I am unsure how to name MMU things ;-) to work with. In my previous version I used them as 256-stack. Start at 0 with a default memory layout (which mem-pages go where in CPU address space). When a change in layout is requested I created it in slot 1 and activated it. When the code was done that requested the new layout, I popped it of the stack to go back to the previous configuration.
Any thoughts on this mechanism?

GitHub Copilot: The mechanism is clever and the hardware supports it elegantly — the 8-bit latch value directly addresses the SRAM rows, so each of the 256 "slots" is simply a complete 8-entry page table stored in the SRAM. Terminology-wise: each slot is a **map context**, and your latch holds the **active context ID**.

**What works well:**
- Push/pop maps directly to increment/decrement the latch value — trivial to implement
- Writing a new context is safe while the current one is active, as long as you write to a *different* slot before flipping the latch
- Zero runtime overhead once the latch is set — hardware does everything

**Where the pure stack model gets strained:**

The implicit assumption is that context use is strictly LIFO. It holds for simple "OS borrows control briefly then returns" scenarios, but breaks down with real multitasking — task A → task B → task A isn't a stack, it's a table indexed by task ID. With a stack you'd end up copying contexts around rather than just switching to a known slot.

**A slightly more general model worth considering:**
- Context 0 = kernel/OS, always identity-mapped, safe fallback
- Contexts 1–N = one per task, permanently assigned at task creation
- Task switch = single IO write of the task's context ID to the latch
- No push/pop bookkeeping needed at all

This is actually simpler than a stack and handles both the "temporary remap" case (OS just uses its own context 0) and multitasking uniformly. The CPLD could even auto-switch to context 0 on interrupt assertion, which solves the interrupt-during-page-switch hazard mentioned earlier.

User: I have 4 spare upper address lines on the SRAMs. That would allow for 16 extra versions of the entire MMU stack. That would mean you coud have say 15 tasks and resevere 1 for the os. Does that address (no pun ;-) the concern?

GitHub Copilot: Yes, completely — and it's actually a more elegant architecture than a flat 256 stack.

**What you now have:**
- Upper 4 bits of SRAM address = **task ID** (0–15, 16 tasks)
- Lower 8 bits = **context stack per task** (256 deep)

These are orthogonal concerns implemented in the same hardware at zero extra cost.

**The result:**
- Task switch = change the upper 4 bits only. The per-task context stack is untouched.
- Within a task, push/pop your stack freely — it never interferes with any other task.
- The OS lives permanently in task ID 0 with its own isolated context stack.
- The CPLD holds both values and composes them into the full SRAM address — a simple concatenation.

**The interrupt hazard also solves cleanly:**
On interrupt, the CPLD switches to task ID 0, context 0 — fully deterministic kernel mapping — without disturbing any task's stack pointer. On return, restore the saved task ID and context. No masking needed in software.

**One thought:** 256 context-stack depth per task is almost certainly overkill. If you ever want more tasks, you could split it 5+7 (32 tasks, 128 stack depth) or 6+6 (64 tasks, 64 stack depth) purely in CPLD logic — the SRAM doesn't care how you partition the bits. Worth keeping in mind as the OS design evolves.

User: I was thinking on putting a latch IC on those 4 upper address lines. My feeling is that the CPLD resources will run out quick if you start building  registers..? Is that correct?
When I was just starting with VHDL (EPM240I tried making registers but I depleted almost all CPLD resources with 2 or three. I probably did something wrong..?

GitHub Copilot: Two separate questions with different answers:

**On depleting CPLD resources with registers:**
Registers themselves are tiny — 1 macrocell per bit. A 4-bit register costs 4 macrocells. That's nothing, even on an EPM240. What depleted your resources was almost certainly the *surrounding logic* the synthesizer inferred:

- An incomplete `if` without `else` in a combinatorial process creates **latches**, which are expensive in CPLDs
- A `case` statement over a wide signal (e.g. 8-bit address decode) infers a large priority encoder
- Comparing two buses (`if A = B then`) generates significant combinatorial logic
- Putting too much in one process forces the synthesizer to create complex product terms

The registers weren't the problem — the logic driving them was. With clean VHDL (synchronous processes, complete conditions, explicit resets), a few registers cost almost nothing.

**On the external latch idea:**
It's not wrong, but it's unnecessary on the XC95288XL, and it actually *adds* complexity — the CPLD still needs to generate the latch clock and read back the value, which costs as much as just holding it internally. 

The clean architecture is:
- Task ID register → inside CPLD (4 macrocells)
- Context stack pointer → inside CPLD (8 macrocells)
- CPLD outputs the full 12-bit SRAM address directly

That's 12 macrocells out of 288. You have plenty of room.

User: Can you give me VHDL example of a 8bit register and an 8bit latch?
I want to experiment and seewhat the  sythesis tools says

GitHub Copilot: **8-bit register (synchronous — what you want for task ID / stack pointer):**

```vhdl
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity reg8 is
    port (
        clk   : in  std_logic;
        en    : in  std_logic;
        d     : in  std_logic_vector(7 downto 0);
        q     : out std_logic_vector(7 downto 0)
    );
end reg8;

architecture rtl of reg8 is
begin
    process(clk)
    begin
        if rising_edge(clk) then
            if en = '1' then
                q <= d;
            end if;
        end if;
    end process;
end rtl;
```

**8-bit latch (level-sensitive — transparent while en=1):**

```vhdl
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity latch8 is
    port (
        en    : in  std_logic;
        d     : in  std_logic_vector(7 downto 0);
        q     : out std_logic_vector(7 downto 0)
    );
end latch8;

architecture rtl of latch8 is
begin
    process(en, d)
    begin
        if en = '1' then
            q <= d;
        end if;
    end process;
end rtl;
```

**Key differences to watch in synthesis:**
- The register will infer 8 flip-flops — cheap and clean
- The latch will infer 8 latches — CPLDs handle these but they're less predictable timing-wise; ISE may warn about them
- Notice the latch has no `else` — that's *intentional* and correct for a latch, but the same omission in a register process is a common mistake that creates unintended latches

The register is almost certainly what you want in the CPLD. Compare the macrocell counts the synthesizer reports for each.

User: please generate a file in the Quartus 15 folder (I only see one of the examples in the chat)

GitHub Copilot: Searched for files matching `**/Quartus 15/**`, 20 matches

Created [](file:///c%3A/My/MyProjects/Zalt/Decoder%20Board%20v1.0%20-%20locked/Quartus%2015/reg8.vhd)

Created [](file:///c%3A/My/MyProjects/Zalt/Decoder%20Board%20v1.0%20-%20locked/Quartus%2015/latch8.vhd)

Created both in [Decoder Board v1.0 - locked/Quartus 15/](Decoder Board v1.0 - locked/Quartus 15/):
- [reg8.vhd](Decoder Board v1.0 - locked/Quartus 15/reg8.vhd) — synchronous register
- [latch8.vhd](Decoder Board v1.0 - locked/Quartus 15/latch8.vhd) — transparent latch

Add both to your Quartus project, compile, and check the **Flow Summary** — it will tell you exactly how many logic elements / macrocells each consumes. The difference should be striking.

Made changes.

User: Thanks. If this works out, I will probably completely remove all external latches and buffers

GitHub Copilot: That would be a clean simplification. The XC95288XL has plenty of I/O drive strength (up to 24mA per pin) so it can directly drive the SRAM address lines without external buffers. The only external parts you'd likely keep are:

- **Bypass capacitors** — still needed on CPLD power pins
- **Pull-up/pull-down resistors** on JTAG and any unused I/O
- Possibly a **bus transceiver for the Z80 data bus** if the CPLD is sharing it with other devices and you need bus isolation, but even that may be avoidable depending on your full board topology

The schematic would become very tidy — Z80 bus straight into CPLD, CPLD address outputs straight to main memory. Hard to argue with that.

User: I've added them into one (example) file. Could you add an OE for high Z outputs?

GitHub Copilot: Replacing 41 lines with 51 lines in [](file:///c%3A/My/MyProjects/Zalt/Decoder%20Board%20v1.0%20-%20locked/Quartus%2015/reg%20and%20latch8.vhd)


```

```
The key pattern is the internal signal `q_int` that holds the value, and the conditional concurrent assignment:
```vhdl
q <= q_int when oe = '1' else (others => 'Z');
```

This keeps the OE logic cleanly separated from the storage logic. Note that tri-state outputs on a CPLD are only meaningful on pins that connect to a shared bus — if OE is used purely internally the synthesizer will likely optimize it away or warn. That's expected behavior.

Made changes.

User: What signals would be required on the expansion bus to extent the MMU address lines to be able to address even more memory?
I am thinking to add a separate MMU extension connector for modules that require large amounts of extra  mem

GitHub Copilot: Good architectural thinking. Here's what the expansion connector needs:

**Minimum signals for MMU address extension:**
- **MA[x..0]** — the translated upper address lines from the CPLD (output from main board)
- **A[12..0]** — the raw Z80 lower address lines (output from main board, passed through)
- **~MREQ, ~RD, ~WR** — bus cycle qualifiers so the expansion module knows when the address is valid and the direction
- **~WAIT** — so the expansion module can insert wait states if its memory needs it
- **D[7..0]** — data bus (bidirectional)
- **~BUSACK, ~BUSREQ** — if a module ever needs DMA
- **CLK** — system clock
- **GND, VCC**

**For the extension concept specifically:**
The expansion module would take the existing MA lines and *add more bits on top* — so the connector also needs:
- **MA_EXT[n..0]** — additional address bits driven *by the module back to the main board* to extend the physical address space beyond what the main board CPLD handles
- Or alternatively: the CPLD outputs spare address bits to the connector that the module simply routes to its own memory, keeping the main board as master

The second approach is cleaner — the CPLD always drives the full address, the expansion module is passive. This means the CPLD needs to have enough spare I/O pins to output the extended MA lines to the connector even before any module is attached.

**Practical note:** If the connector carries the full translated MA bus plus the raw lower 13 bits, the expansion module needs nothing else to independently address its memory — it just decodes what it needs and responds on the data bus. That's the most flexible arrangement.

User: I am not following. How would executing code access the extended MMU logic?

GitHub Copilot: You're right to push back — I conflated two different things. Let me be precise.

**The fundamental constraint:**
The Z80 only has 16 address lines — 64KB logical address space, fixed. No amount of expansion connector cleverness changes that. Code *executes* within that 64KB window regardless of how much physical memory exists.

**What the MMU actually does:**
It remaps those 8 logical pages to *different* physical pages. The extended MA lines just mean the physical memory pool is larger — but the Z80 still only *sees* 64KB at a time. To access memory beyond the current mapping, software explicitly reprograms the MMU (IO write to the CPLD) to swap in a different physical page, then accesses it through the same 64KB window.

**So the expansion connector question reframes:**
There's no "extended MMU logic" that the Z80 executes through transparently. What an expansion module actually provides is simply **more physical RAM** that the MMU can point pages at. The connector just needs:

- The full physical address bus (MA lines + A12..0) so the module can decode which physical address is being accessed
- **~CS** or address decode signals so the module knows when it's being addressed
- **D[7..0], ~RD, ~WR, ~WAIT, GND, VCC**

That's it. The module is just a passive memory bank — the MMU on the main board already handles all the address translation. The expansion module never needs to know anything about the MMU itself.

User: We now have say 28 memory address lines. What if we need 32?

Or would an extension mean that a reserved (extended) memory page it tunnels through to another MMU that allows mapping additional memory into the one spot? (would work but a bit limiting)

GitHub Copilot: Your instinct at the end is exactly right, and it's actually the standard solution.

**Going from 28 to 32 address lines directly:**
That means 4GB of physical memory. The SRAM lookup table approach doesn't scale — you'd need a 32-bit wide SRAM output, which means more SRAM chips, a wider latch, and a CPLD with enough I/O to drive 32 address lines plus everything else. Physically possible but the board gets complex fast.

**The "tunnelled page" approach — which is what you described:**
Reserve one (or a few) logical pages as an "expansion window." When the MMU maps that page to a special decoded address range, it asserts a signal that activates a second-level MMU on the expansion module. That module has its own lookup table and handles the final physical address within its own memory space.

This is essentially a **two-level MMU** — exactly how modern CPUs handle it (page directory → page table). The Z80 doesn't know anything changed; it just accesses the window address normally.

**The tradeoff you identified is real but manageable:**
Only one expansion window active at a time *per page slot*. But if you reserve 2-3 logical pages as expansion windows, each pointing to a different module, you effectively have multiple independent extended address spaces visible simultaneously.

**Honest assessment:**
For a Z80 homebrew, 28 address lines is 256MB of physical RAM. That's already far beyond anything you'll practically populate. The tunnelled page approach is elegant on paper but adds real complexity for a use case you're unlikely to hit. I'd design the connector to carry all current MA lines and leave a few spare pins for future expansion signals — and cross that bridge only if you actually need it.

User: Yes, the question was more a though experiment that a real need or requirement. Still I would like to avoid to make extensions imposible by choices I have to make now.
One thing I was also thinking of was a similiar case to the old PC VGA cards. They had on-board programming (drivers) in ROM that was mapped into the CPU address space. But our tunneled solution is probably fine for that

GitHub Copilot: Yes, the tunnelled window is exactly what the PC option ROM mechanism was — the BIOS scanned specific address ranges (C0000h–EFFFFh), found a ROM header signature, and mapped it in. VGA BIOS, SCSI controllers, network cards all used it. Same concept, different scale.

**For your design, "don't close doors" means:**

The connector should carry:
- All current MA lines
- **A dedicated "expansion active" signal from the CPLD** — asserted when the MMU has mapped to the expansion window address range. This is the trigger for a module to wake up its own address logic.
- A few **spare pins** (4-6) with no defined function yet

That's it. Those spare pins and the expansion-active signal are the hook that keeps the tunnelled approach possible later without a board respin. The module can use them however it needs — second-level MMU address bits, ROM-present detection, interrupt lines, whatever the use case turns out to be.

**On the option ROM case specifically:**
Your tunnelled window handles it cleanly — a module with ROM simply responds when expansion-active is asserted and puts its data on the bus. The main board CPLD doesn't need to know it's ROM vs RAM. The OS probes the window, finds a signature, and treats it accordingly. No special hardware needed beyond what you're already planning.