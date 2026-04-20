User: The MMU manages 8k memory pages. Any memory page can be put anywhere in the CPU address space.
I could see a situation arise where memory pages are swapped in and out (and back in) but on different cpu page addresses. So a page could be used in the position 0 ($0000), swapped out -something else being swapped back in on $0000) and the that initial memory page is put in say $4000.
Note also that each memory page has control bits that allow the program to read, write and/or execute in that memory page.
In order for memory pages to be movable/relocatable the program needs to confirm to a set of requirements.
That set of requirements are dependent on how we solve the problem. Any ideas/suggestions on how this could be solved?

GitHub Copilot: This is a classic relocation problem. Here are the main approaches, with trade-offs:

---

## Option 1: Position-Independent Code (PIC)

The gold standard. Code has **no hardcoded absolute addresses**.

**Requirements on code:**
- All jumps/branches within a page use **PC-relative** addressing only
- Data within the same page accessed via a **base pointer register** (set at entry to point to the page's data section)
- **No absolute address literals** stored in code or data tables

**Cross-page calls** require an indirection layer — each page has a small **Procedure Linkage Table (PLT)** at a fixed page-relative offset (e.g., first 64 bytes). Calls to other pages go through the PLT, which the OS patches with the correct current address when mappings change.

**Pros:** Pages can be remapped with zero fixup work at swap time.  
**Cons:** Requires CPU to support relative branches/calls. Your assembler/compiler must enforce these constraints.

---

## Option 2: Relocation Records (Load-time / Swap-time Patching)

Each 8K page begins with a **relocation table** — a list of offsets within the page where absolute addresses are embedded. When a page is mapped to a new slot, the OS walks the table and patches each address.

**Page header structure example:**
```
[0x0000]  Page ID (2 bytes)
[0x0002]  Relocation record count (2 bytes)
[0x0004]  Relocation records: list of (offset, type) pairs
[...]     Code/data follows
```

**Pros:** Code can use absolute addressing freely; no CPU ISA constraints.  
**Cons:** Page must be writable during relocation. Swap latency increases. Records must be complete and correct — a missed record corrupts the page.

---

## Option 3: All Cross-Page References via a Fixed Dispatch Page

Reserve one MMU slot (e.g., slot 0 or the top slot) permanently for an **OS dispatch page**. All inter-page calls are *always* routed through it.

Each logical "module" registers its entry points with the dispatcher on load. Cross-page calls are:
```
CALL dispatch_page + function_vector_offset
```
The dispatcher looks up the current slot of the target page in the MMU table at runtime.

**Pros:** No relocation fixup at all — pages are fully opaque. R/W/X bits are enforced at the dispatcher boundary.  
**Cons:** Every cross-page call has OS overhead. The dispatch page is a fixed resource.

---

## Recommended Hybrid

Given you have hardware R/W/X bits per page and a CPLD-based MMU:

1. **Mandate PIC within a page** — relative jumps only, base-register for data. This is the non-negotiable core requirement.
2. **Standardize a page header** at offset 0 of every page containing: page ID, version, exported function jump table, and required page dependencies (logical IDs, not slot addresses).
3. **Cross-page calls always indirect** — caller doesn't know the target's current slot; it calls through the local PLT which the OS updates on remap.
4. **OS maintains a logical page registry**: `logical_page_id → current CPU slot`. Remapping a page = update registry + patch all PLT entries that reference it.

This means **the only thing that changes on a remap is MMU slot registers and PLT entries** — no code patching, no relocation records. The R/W/X bits also slot naturally: the execute bit enforces that only properly-headed pages run as code.

---

## Summary of Code Requirements

| Requirement | Rationale |
|---|---|
| PC-relative branches/calls within page | Page-internal jumps remain valid after remap |
| Base-register-relative data access | Data addresses don't hardcode the page's slot |
| Cross-page calls only via PLT indirection | Caller is insulated from target's current slot |
| Page starts with header + export jump table | OS can manage, identify, and patch pages |
| No absolute address literals in code | Eliminates need for relocation records |

The biggest design decision is whether your CPU ISA supports PC-relative addressing — if it doesn't, Option 2 (relocation records) becomes necessary for intra-page data references.

User: The CPU is a Z80 and the compiler I plan to  use is the z80asm from z88dk. I would prefer a solution that does not require any runtime support from the module itself. The information needed is in the program file (reloc tables) and the os (loader) can perform the required actions based on that info. The os can temp disable/change the memory protection bits (R/W/X) when pages are swapped/moved. Does that change your suggestions?

GitHub Copilot: Yes, significantly. This narrows it to **Option 2 (relocation records)** as the only practical choice, and the good news is z80asm is already built for it.

---

## Why Z80 Forces Relocation Records

The Z80 has only two short-range relative instructions (`JR` and `DJNZ`, ±127 bytes). Every `CALL`, `JP`, and 16-bit immediate load is an absolute address embedded in the code stream — so PIC within an 8K page is impossible in the general case. Patching at load/remap time is the right answer.

---

## z80asm Already Does This

z80asm from z88dk has `--reloc-info` which emits a relocation table alongside the binary. It lists every offset within the output where a 2-byte absolute address is embedded and needs fixup. This is exactly the input your loader needs.

```
z80asm --reloc-info mymodule.asm
```

Produces `mymodule.bin` + `mymodule.reloc` (list of offsets needing patching).

You'd incorporate the relocation table into your page binary format so everything is self-contained.

---

## Page Binary Format (8K)

```
Offset  Size  Field
------  ----  -----
0x0000  2     Magic (e.g. 0xA55A)
0x0002  2     Page ID (logical identifier)
0x0004  2     Linked-at base address (the address z80asm assumed)
0x0006  2     Number of relocation entries (N)
0x0008  2*N   Relocation table: page-relative offsets of each abs address
0x0008+2N ...  Code/data (rest of the 8K page)
```

The header itself contains no absolute addresses, so it never needs patching.

---

## Loader Algorithm

When mapping a page to a new CPU slot (base = `slot * 0x2000`):

```
linked_base = page_header.linked_at_base
new_base    = target_slot * 0x2000
delta       = new_base - linked_base

// Temporarily enable write on this page
mmu.set_rwx(page, READ | WRITE)

for each offset in relocation_table:
    addr = page_memory + offset
    *addr = *addr + delta        // 16-bit add, patch in place

// Restore correct protection bits
mmu.set_rwx(page, page_header.protection_bits)
mmu.map(page, target_slot)
```

`delta` is a signed 16-bit value — if the page was linked at `0x0000` (simplest choice), then `delta` is simply the new slot base.

---

## Linking Convention

Link all pages with origin `0x0000` (or any consistent base):

```
z80asm --origin=0x0000 --reloc-info mymodule.asm
```

This maximizes the delta range and simplifies loader math. The header stores `linked_at_base = 0x0000` and the loader just adds the target slot address to every relocated word.

---

## The Remaining Hard Problem: Cross-Page Calls

Intra-page code is fully solved by the above. Cross-page calls are harder because `CALL 0x4123` in page A refers to a specific slot of page B — if page B moves, page A breaks.

Three options, from simplest to most robust:

| Approach | How it works | Loader cost |
|---|---|---|
| **Rebind on remap** | Track which pages import from each page; re-patch importers when target moves | Requires dependency graph |
| **Fixed kernel dispatch page** | One permanently-mapped page holds a jump table; cross-page calls go `CALL dispatch+N`; only dispatch table is patched | Dispatch page is a fixed MMU slot |
| **Import stubs with per-page import table** | Page header includes import table (target page ID + export index); loader patches local stubs; stubs are in the reloc table | Clean but more complex header format |

For a start, the **fixed dispatch page** is the simplest: it costs one MMU slot but means no page ever needs to know another page's current slot — only the OS dispatch table gets updated on remap.

User: That would mean splitting the .reloc file the asm80 outputs and put 'pieces' of it  with code that fits in the 8k chunks. How would you do that optimally? Do you  have to be explicit when writing the program or is there a control-flow algorithm that can analyse the code and determine an optimal way to pack the 8k chunks?
Also how do you deal with calls to parts of the program that are currently swapped out?

GitHub Copilot: Two separate problems. Let me address each.

---

## 1. Splitting into 8K Chunks

### Can it be automatic?

Theoretically yes, but practically no — and here's why:

Optimal packing is a **graph partitioning problem**: minimize cross-page edges (calls) while keeping each partition ≤ 8K. This is NP-hard in general. Even if you built a tool to do it, it would need a complete call graph — which is undermined by indirect calls (`JP (HL)`, `CALL (IX+n)`, function pointers in C), which are unresolvable statically.

**The right answer is: be semi-explicit at the source level.** This is exactly what z80asm's section/module system is designed for, and it's how every professional overlay system on Z80 was built.

### Practical approach with z80asm

Declare named sections in source; the linker script assigns them to specific 8K windows:

```asm
; module_a.asm
SECTION page_1
    ; all code/data here belongs to page 1
PUBLIC fn_foo
fn_foo:
    ...
```

In your linker script (`.lst` file):
```
SECTION page_0 org 0x0000 ; linked base always 0x0000
SECTION page_1 org 0x0000 ; same — each page assumes it's at 0x0000
SECTION page_2 org 0x0000
```

Each section produces its own binary + its own slice of the reloc table.

### Post-link splitter tool

You write a small host-side tool (Python is ideal) that:

1. Reads the z80asm map file to know section start/end offsets in the flat binary
2. For each page section, extracts that byte range from the binary
3. Filters the `.reloc` entries to only those whose offset falls within that range, rebases them (`entry_offset - section_start`)
4. Prepends the page header and writes the final `.page` binary

```python
for page in pages:
    relocs_for_page = [r - page.start for r in all_relocs 
                       if page.start <= r < page.end]
    write_page_file(page.id, code[page.start:page.end], relocs_for_page)
```

The key insight: because every section is linked at `org 0x0000`, reloc offsets are already page-relative — no rebase math needed. The splitter just filters.

---

## 2. Calls to Swapped-Out Pages

This is the hard problem. On Z80 there's no built-in page-fault mechanism, so you have two realistic options:

### Option A: Hardware-assisted fault (best fit for your system)

Your CPLD MMU already has the X bit. Extend it: when the CPU attempts an **instruction fetch** from a page with X=0, the CPLD asserts **NMI** instead of returning data.

The NMI handler (permanently resident, in a fixed MMU slot) becomes your demand-loader:

```
NMI fires →
  Read the address the CPU was trying to fetch (from MMU fault register)
  Determine which logical page owns that address
  Find/evict a physical page slot (LRU)
  Load the required page binary from storage
  Patch reloc table (delta from linked base to new slot)
  Set X=1, restore R/W bits
  RETN  ← Z80 NMI return, retries the faulting instruction
```

This is **completely transparent to the program**. A `CALL 0x4123` just works — if the target page isn't loaded, hardware traps, OS loads it, execution continues. No stub, no indirection, no programmer awareness required.

**CPLD change needed:** A small fault-address latch register + NMI line assertion on X=0 fetch. Given you already have the MMU CPLD, this is a firmware change, not a hardware redesign.

### Option B: Software overlay manager (no CPLD change)

Reserve one MMU slot permanently for a **resident overlay manager**. All cross-page calls are written through it:

```asm
; Instead of: CALL some_fn_in_page_3
LD  BC, PAGE_3_ID << 8 | FN_FOO_INDEX
CALL overlay_mgr   ; resident at fixed address
```

The overlay manager checks a page-present table, evicts/loads as needed, then jumps to the real function. On return, it returns to the original caller.

**Downside:** Every cross-page call requires programmer discipline (no transparent `CALL`), and call overhead is significant.

---

## Recommendation

| Concern | Recommendation |
|---|---|
| Page splitting | Semi-explicit: group related code into named sections by function domain (UI, filesystem, math, etc.). Let the linker + splitter tool handle the mechanics. |
| Cross-page calls | Add X-fault → NMI to the CPLD. It's a clean hardware solution that requires zero runtime support from user code — which is exactly your stated requirement. |
| Eviction policy | LRU is fine; track last-used tick per loaded page in the OS resident area. |

The NMI demand-loader approach means your relocation+page-header format fully satisfies the "all info in the file, loader does the work" constraint, and the program itself needs no awareness of paging at all.

User: I don't see option A working. The code that is executing the call/jp already has the X=1 on that mem-page.
The target it is jumping to might also be a random code (X=1) page and it would land somewhere random...
I would love to solve this with hardware (I still have the option to make changes) but I am not seeing this.
Option B: That would not be C-compatible. I want the user application to be written with C. The OS can be asm.
I also don't see how you detect a cross memory page call when all chunks have org=$0000?

GitHub Copilot: You're right on all three points. Let me correct each:

---

## Option A — Why It Truly Doesn't Work

Your diagnosis is correct. The fatal flaw: when a page is evicted and a **different** page (also X=1) occupies that slot, the CPU silently executes the wrong code. The X-bit only means "some executable page is here," not "the correct page is here." There's no trap, no NMI — just corrupt execution. To fix this in hardware you'd need per-slot page-ID registers and a match-check on every instruction fetch, which is a substantially more complex MMU design.

**Option A is not viable without significant extra hardware.**

---

## Option B — It IS C-Compatible

The confusion is about what "dispatch" means at the C level. C code never sees the dispatch mechanism:

```c
// user code — just a normal function call
int result = fs_open("file.txt", MODE_R);
```

The C compiler emits `CALL fs_open`. The **linker** resolves `fs_open` — not to the real function address, but to a stub in the dispatch page. The C programmer writes normal C. This is identical to how Windows DLL import stubs (`__imp_foo`) or Linux PLT entries work. The indirection is entirely a linker artifact.

The dispatch page (permanently mapped, e.g. always slot 7 = `0xE000`):
```asm
; dispatch page, assembled once, never moves
fs_open_stub:   JP 0x0000   ; OS patches this when fs module loads
fs_close_stub:  JP 0x0000
; etc.
```

The linker resolves `fs_open` → `0xE000`, `fs_close` → `0xE003`, etc. C code calls `CALL 0xE000`, always correct, no reloc needed for these.

---

## The org=$0000 / Cross-Page Detection Problem — Solved By the Same Mechanism

This is the sharpest observation. With all pages at `org=$0000`, a `CALL 0x0500` in the reloc table could mean "intra-page" or "into another page also at $0000" — indistinguishable.

The dispatch page resolves this entirely:

- **Intra-page calls**: target is within `0x0000–0x1FFF` (the page's own org range) → appears in reloc table → loader patches on placement
- **Cross-page calls**: target is always `0xExx` (dispatch stubs, fixed slot) → does NOT appear in reloc table → always correct regardless of where the calling page is placed

You achieve this in z80asm by declaring dispatch stubs as `DEFC` equates (constants), not as `PUBLIC` code labels from a linked module:

```asm
; in a shared header, included by all modules
DEFC fs_open  = 0xE000   ; dispatch stub address, a constant
DEFC fs_close = 0xE003
```

Because these are compile-time constants (not section-relative labels), z80asm does not emit reloc entries for them. Only section-relative addresses generate reloc records.

---

## How It Fits Together

```
┌─────────────────────────────────────────────────────┐
│  Slot 7 (0xE000): Dispatch page — ALWAYS mapped     │
│    fs_open_stub:  JP [current addr of fs_open]      │
│    ...                                               │
├─────────────────────────────────────────────────────┤
│  Slots 0–6: Swappable pages, each independently     │
│    linked at org=0x0000                             │
│    Reloc table: intra-page refs only               │
│    Cross-page calls: CALL 0xExx (no reloc entry)   │
└─────────────────────────────────────────────────────┘
```

**When a page loads into slot N:**
1. OS temporarily sets W=1 on the slot
2. Patches each reloc entry: `*addr += (N * 0x2000)` 
3. Restores correct R/W/X bits
4. Updates dispatch page stub(s) for functions in this page: `JP (N * 0x2000 + fn_offset)`

The C programmer writes normal C. The OS and linker script carry the entire burden.

User: Hmm - I need to study this some more - I do not see it yet.
In the meantime I had an idea: would it help if we have an extra memory-protect bit (like R/W/X) for each memory-page that we could utilize for this mechanis? Because that option is still open.

GitHub Copilot: Yes, a new bit changes the picture significantly. Let me work through what it enables.

---

## The New Bit: P (Present)

Call it **P** — distinct from X (executable). Semantics:

- **P=1**: the correct page for this slot is loaded, normal R/W/X rules apply
- **P=0**: this slot is empty/evicted — any CPU access (fetch, read, write) causes the CPLD to assert NMI instead of completing the bus cycle

---

## What This Enables: Fixed-Slot Demand Paging

With P, you can adopt a policy that sidesteps the entire cross-page call problem:

**Each logical page has a permanently assigned slot.** Page B always lives in slot 2 (`0x4000–0x5FFF`). It can be evicted (P=0), but when reloaded it always comes back to slot 2.

The flow:

```
1. Page A executes CALL 0x4500  (page B, offset 0x0500)
2. Slot 2 is evicted → P=0
3. CPU tries to fetch at 0x4500 → CPLD sees P=0 → asserts NMI
4. NMI handler: "slot 2 is empty, its owner is page B"
5. Load page B from storage back into slot 2
6. Set P=1, restore R/W/X
7. RETN → CPU retries CALL 0x4500 → succeeds
```

This is **completely transparent to C code.** A normal `CALL` just works.

---

## Why This Solves All the Earlier Problems

| Problem | Solution |
|---|---|
| CALL lands in wrong page | Can't happen — slot 2 is either page B (P=1) or empty (P=0, NMI fires) |
| Cross-page call detection | Not needed — calls target fixed addresses that never change |
| Reloc patching on reload | Delta=0 (same slot always) — **no patching needed on swap-in** |
| Dispatch page needed | No — pages call each other directly at fixed addresses |
| C compatibility | Full — programmer sees nothing |

Relocation patching only happens **once**: when the page is initially placed into its assigned slot (linking at `org=0x0000`, delta = `slot * 0x2000`). After that, evict/reload cycles are zero-cost in terms of patching.

---

## The Trade-off

Pages cannot be dynamically **relocated** to a different slot at runtime. Slot assignments are fixed at load time (by the OS or at link time). This is a real constraint, but for most use cases (swapping idle code out to free RAM) it's perfectly acceptable.

If you ever *do* need to move a page to a different slot (e.g., defragmentation), the OS can:
1. Set P=0 on the old slot
2. Load the page into the new slot, re-run the reloc patch with the new delta
3. Update the OS slot-assignment table
4. Any subsequent NMI for the old slot now redirects to the new slot

---

## CPLD Change Required

Minimal: add one latch register per slot for P, and combinatorial logic:

```
if (CPU_ADDRESS falls in slot N) AND (P[N] == 0):
    assert NMI
    latch fault_address
    stall bus (hold /WAIT until NMI acknowledged)
```

The NMI handler reads `fault_address` from an MMU I/O register to know which slot faulted.

This is a small addition to your existing MMU CPLD logic — you already have per-slot R/W/X bits, so P is just a fourth bit with different assertion logic.

User: Hmm, I have 32MB of address space (with the P -bit). That puts a lot of pressure on those 8 memory blocks that fit in the CPU address space - probably less because of one (or more?) fixed blocks for the OS.
Well, its something to think about.

GitHub Copilot: Yes, that's the core tension. With fixed-slot assignment:

- 8 slots total, maybe 2 reserved for OS (NMI handler, dispatch/kernel)
- **6 slots for user code** — meaning only 6 logical pages can ever be "known" to a running program, regardless of how much RAM is installed
- 32MB of RAM becomes largely inaccessible beyond those 6 × 8KB windows

---

## The Real Trade-off

| Approach | Logical pages accessible | Complexity |
|---|---|---|
| Fixed-slot + P-bit | ~6 (forever) | Very low |
| Dynamic-slot + dispatch page | Thousands (all of 32MB) | Moderate |
| Hybrid | See below | Moderate |

With 32MB available, fixed-slot assignment is genuinely wasteful. You'd be ignoring ~99.9% of your RAM.

---

## A Practical Hybrid

- **Slots 0–1**: OS resident (kernel, NMI handler) — fixed, always P=1
- **Slot 2**: Dispatch page — fixed, always P=1  
- **Slots 3–7**: Dynamic — any logical page can rotate through these

This gives you dynamic access to all of 32MB through 5 swappable slots, a permanent dispatch stub table for cross-page calls, and the P-bit still works perfectly — each slot either has the right page (P=1) or fires the NMI demand-loader.

The cost is the dispatch page complexity discussed earlier, but that's entirely an OS/linker concern — C code still sees nothing.

---

The P-bit idea is still very valuable in this hybrid model. It's what makes the demand-loading transparent.

User: After rereading what we've been discussing - I don't understand it.
The P-bit indicates if a mem-page is loaded? All 8 mem-pages will be loaded. The question to answer is: is the correct mem-page (in the correct spot) for this cross mem-page call? If not, we need to change the MMU mapping and swap that block in. That new block will also have its P-bit set? I don't think we need a 'hardware' bit to indicate if a mem-page is occupied. The OS will have to keep track of these things anyway.
Or am I totally missing the point?

GitHub Copilot: You are not missing the point — you have identified a flaw in my explanation.

You're right: all 8 slots always have *some* physical RAM mapped. There is no "empty" slot. So a hardware "present" bit indicating whether RAM is there makes no sense.

---

## The Real Problem

The issue is not "is there RAM in slot 2?" — it's "is the **correct** page in slot 2?"

If page A executes `CALL 0x4000` expecting page B, but the OS has since swapped page C into that slot, the CPU just silently executes page C's code at offset 0x0000. No trap, no detection — just corruption.

The OS can track placement in a software table, but that table is only consulted when the OS is running. It cannot intercept a mid-stream `CALL` in user code.

---

## So What Does the P-bit Actually Buy You?

A better name would be **V (Valid)** — "this slot contains the page that code is allowed to call into." When the OS evicts page B from slot 2, it sets V=0 on that slot. Page C is now physically there, but the CPLD will fire an NMI on any access to that slot, giving the OS a chance to fix the mapping before the CPU executes the wrong code.

Without V, there is no hardware intercept point. The CPU just runs whatever is there.

---

## Without the V-bit, Your Only Options Are:

| Option | How cross-page calls work |
|---|---|
| **Fixed-slot assignment** | Page B is *always* in slot 2, never evicted to make room for something else. OS only evicts from "free" slots. Limits concurrent logical pages to ~6. |
| **Dispatch page** | Calls never target swappable slots directly. All cross-page calls go through fixed stubs. OS updates stubs on remap. Requires linker cooperation. |

The V-bit is what enables a third option: fully dynamic slot assignment with transparent `CALL`s. Without it, one of the two above is the right path.

User: You can give it another name, but can the the V-bit answer the question. Is the (correct!) call target available and where is it?

GitHub Copilot: No — and that's the key limitation. The V-bit can only answer half the question.

**"Is the correct target available here?"** → Yes, the V-bit answers this. V=1 means the OS declared this slot valid; V=0 fires the NMI before wrong code executes.

**"Where is it?"** → The V-bit cannot answer this. That is always a software table in the OS.

---

## What Actually Happens on an NMI

```
CALL 0x4000 → slot 2 has V=0 → CPLD fires NMI
NMI handler:
  1. Reads fault address (0x4000) from MMU register
  2. Looks up software table: "slot 2 should contain page B"
  3. Finds where page B currently is: in RAM bank 17, or on storage
  4. Maps page B into slot 2, patches relocs if needed
  5. Sets V=1 on slot 2
  6. RETN → CPU retries CALL 0x4000 → correct page, succeeds
```

The V-bit is the **trap mechanism**. The software table is the **directory**. You need both — the bit alone cannot locate the page, and the software table alone has no way to intercept the CPU mid-execution.

Together they give you fully transparent demand-paging with correct page validation.

User: Sorry, You have not convinced me that a hardware bit will fix this. When a blcok is evicited, it is because some other block was needed at that time - its V/P-bit will be set. Then when a target needs to be called that is not available in the CPU address space, it will have to be moved in - it will replace some other block (least used - whatever). My Point: how can one bit -bound the memory page  (not the block position in cpu space) indicate that the target that is about to be called, is the correct one for that specific call? It was the the correct block for the previous call (so its V bit is set)... now what?

GitHub Copilot: You are completely right. I was wrong to keep defending the V-bit as a solution to this.

Here is the honest analysis:

---

## Why No Single Hardware Bit Can Solve This

When `CALL 0x4000` executes, the CPLD sees an address. It has no knowledge of **which page the caller intended to reach**. It can only see what is currently in that slot. If page D is there with V=1, from the hardware's perspective everything is fine — it has no idea page B was expected. The bit is per-slot, but the "correctness" question is per-call. Those are fundamentally different things.

No amount of bits-per-slot solves this unless the hardware also knows the caller's intent — which it can't, without changes to the Z80 ISA itself.

---

## The Two Real Solutions (no other options)

**Fixed slot assignment:**
Each logical page has a permanently assigned slot. `CALL 0x4000` always means page B, unconditionally, because page B never moves to a different slot. It can be evicted (V-bit fires NMI, OS reloads it *back into slot 2*), but it never relocates. The V-bit works correctly here because "is slot 2 occupied by page B?" is always the right question.

Cost: ~6 concurrent logical pages from 32MB of RAM.

**Dispatch page:**
No user code ever calls a swappable slot directly. All cross-page calls target fixed stubs. The OS updates stub jump targets on every remap. Fully dynamic, accesses all 32MB. Requires linker cooperation but is transparent to C.

---

There is no third option that is both hardware-simple and fully dynamic. You pick one constraint to live with: limited concurrent pages, or a dispatch page.

User: ok - dispatch page it is. 
I can see this linker trickery working with one program. All the locations for all the calls can be fixed in the dispatch page.
But what about when loading multiple programs (I aim to do multi-tasking) and/or have shared modules (libraries) that can be called by multiple applications. Now the static location/address assignment in the dispatch page has to be 'relocated' (pun intended  ;-)

GitHub Copilot: Great question, and it cascades into the full OS design. Here's how it breaks down:

---

## The Core Issue

A static dispatch page works for one program because all addresses are known at link time. With multiple programs and shared libraries, you have two distinct problems:

1. **Each process has different internal cross-page calls** — process A's stubs are meaningless to process B
2. **Shared library stubs must be consistent across all processes** — but the library page may be in different slots for different processes

---

## Solution: Two-Tier Dispatch

### Tier 1 — Per-Process Dispatch Page

Each process owns one dispatch page in physical RAM. On a **task switch**, the OS simply remaps the dispatch slot to the new process's dispatch page. Process A's stubs are active while A runs; B's stubs while B runs.

```
Task switch:
  MMU slot 6 ← Process A dispatch page   (while A runs)
  MMU slot 6 ← Process B dispatch page   (while B runs)
```

Process-internal cross-page calls work identically to the single-program case. The dispatch page is just another swappable page from the MMU's point of view.

### Tier 2 — OS/Shared Library Page (Fixed, Never Swapped)

One permanently mapped slot holds the **OS/library dispatch page**. This is fixed for all processes at all times:

```asm
; OS dispatch page — permanent, slot 7 = 0xE000
fs_open:    JP 0x0000    ; OS patches when fs module loads
malloc:     JP 0x0000
libc_memcpy: JP 0x0000
```

All processes resolve shared library calls to `0xE000+N` at link time via a system-wide header. This address never changes regardless of which process is running.

---

## Shared Library Page Movement

When the OS moves a shared library page to a different slot, it patches **only the OS dispatch page** — one place, one patch. All processes benefit automatically because they all call through the same Tier 2 stubs.

```
fs module moves from slot 3 to slot 5:
  OS dispatch page: fs_open stub → JP 0xA000  (was 0x6000)
  Done. All processes now reach fs correctly.
```

---

## Module Registry

The OS maintains a table in its resident area:

```
Module ID | Name      | Physical RAM bank | Exports (offset list)
----------|-----------|-------------------|----------------------
0x01      | fs        | bank 4            | open@0x00, close@0x03 ...
0x02      | libc      | bank 7            | memcpy@0x00, strlen@0x03 ...
```

When a module loads: allocate OS dispatch stubs, populate registry, patch stubs.  
When a module moves: find its registry entry, repatch its stubs. One operation.

---

## Summary

| Call type | Dispatch tier | Stub location | Changes on task switch? | Changes on lib move? |
|---|---|---|---|---|
| Intra-process cross-page | Per-process page | Slot 6 (remapped) | Yes (whole page swaps) | No |
| OS / shared library | OS page | Slot 7 (fixed) | No | Stubs patched once |

The per-process dispatch page costs you nothing extra — it's just one of the process's own pages. The OS dispatch page costs one permanent slot, but you were already planning that for the kernel.

User: FYI:  Each task will have their own private MMU map. So application banks (current configuration of memory page  assignment in cpu address space) will never (have to) conflict. Only the shared module pages will need to be mapped into each program (that uses it). Each task has a 'stack' of 64 different bank configurations it can quickly switch between. Max 64 tasks. A task is more like a process (program). inside the task/program a cooperative mechanism is assumed for sharing time between program 'tasks'. The OS will probably claim a couple of the Tasks.
Tier 2: with one fixed page for shared modules it is required to carefully manage the dispatch location/address of each function stub (across modules).
I was thinking if keeping each mem-page self contained would solve anything. Have not thought it through yet though...

GitHub Copilot: The private MMU map per task changes things significantly. Let me reframe.

---

## Private MMU Maps Eliminate Tier 2 Complexity

Since every task has its own MMU map, shared modules don't need a single global dispatch page. Instead: **every task's MMU map reserves the same slot(s) for each shared module.**

```
Every task's MMU map:
  Slot 7 (0xE000): OS kernel     ← same physical RAM bank, every task
  Slot 6 (0xC000): fs module     ← same physical RAM bank, every task
  Slot 5 (0xA000): libc          ← same physical RAM bank, every task
  Slots 0–4:       task-private pages
```

`CALL 0xC000` always reaches `fs` regardless of which task is running. No dispatch page, no stub patching, no address management complexity. The MMU map *is* the dispatch mechanism.

---

## Self-Contained Pages — Your Intuition Is Right

This is the natural companion idea. Each page exports functions at **fixed intra-page offsets from the page base**:

```asm
; fs module — always mapped at 0xC000
; Export table at page base:
fs_open:    JP _fs_open_impl    ; 0xC000 — callers use this address
fs_close:   JP _fs_close_impl   ; 0xC003
fs_read:    JP _fs_read_impl    ; 0xC006
; ... internal implementation follows
```

Callers compiled with:
```asm
DEFC fs_open  = 0xC000   ; compile-time constant, no reloc entry
DEFC fs_close = 0xC003
```

The page is self-contained: its export table is at known offsets, internal implementation is behind the jump table, and the jump table absorbs any internal layout changes without affecting callers.

---

## What This Costs

Each permanently-assigned shared module slot reduces task-private slots. With 8 slots and say 3 for OS/shared libs, tasks get 5 private slots = 40KB of private code/data space. Whether that's enough depends on your application complexity.

The 64-bank-configuration stack per task helps here — a task can rapidly switch between different arrangements of its 5 private slots, effectively having access to much more than 40KB, just not simultaneously.

---

## Remaining Open Question

What happens when a shared module is updated or a new shared module is loaded dynamically (plugin-style)? With fixed slot assignment, adding a new shared module requires a pre-reserved slot. A small OS-managed shared module slot table (e.g., 3 reserved + 2 dynamic) would handle this cleanly.

User: The data (variables)  should be close to the code - in the same page. But supose you have a large data set (say a bitmap) that would exceed 8k. How would we manage that and the code that points to it trying to read it?

GitHub Copilot: Good question — this is the point where data and code paging diverge, because data doesn't have the "wrong page" call problem. It's simpler.

---

## The Core Insight

Large data doesn't need a fixed slot. You need a **data window** — one (or two) slots reserved as a moveable viewport into any physical data page. This is exactly how EMS worked on DOS.

```
Slot 7: OS kernel          (fixed)
Slot 6: shared modules     (fixed)
Slot 5: data window A      (task remaps this freely)
Slot 4: data window B      (optional second window)
Slots 0–3: code pages      (task private)
```

---

## Accessing a Large Dataset

A 32KB bitmap = 4 × 8KB physical pages. Your code iterates through them:

```c
#define DATA_WIN ((uint8_t*)0xA000)   // slot 5, compile-time constant

void process_bitmap(uint8_t bmp_handle) {
    for (int chunk = 0; chunk < 4; chunk++) {
        os_map_data(bmp_handle, chunk);  // OS remaps slot 5
        for (int i = 0; i < 8192; i++) {
            DATA_WIN[i] = transform(DATA_WIN[i]);
        }
    }
}
```

Within each chunk, `DATA_WIN` is a normal C pointer. No Z80 ISA limitations, no reloc issues — data access is just `LD A, (HL)`.

---

## Pointers Into Data Pages

The problem: a pointer *into* the bitmap (e.g., `uint8_t* row = &bmp[3000]`) is only valid while the right chunk is mapped. If you store that pointer and use it later after a remap, it's corrupt.

Two ways to handle this in C:

**1. Chunk-relative offsets (safest):**
Store `(chunk_index, byte_offset)` pairs instead of raw pointers. Resolve to a real pointer only when accessing, after mapping the correct chunk.

**2. Discipline convention:**
Never hold a cross-chunk pointer across an `os_map_data()` call. Within a single chunk's processing loop, raw pointers are fine. The OS header documents this as a programming rule.

Option 2 is how EMS worked — programmers just knew not to hold far pointers across bank switches. In practice it's manageable.

---

## Data Pages vs. Code Pages: Key Differences

| | Code pages | Data pages |
|---|---|---|
| Fixed slot needed | Yes (for call targets) | No |
| Reloc patching | Yes, on load | No (data has no embedded addresses) |
| Cross-page "call" problem | Yes | No — just remap and read |
| Pointer validity | N/A | Only within current window mapping |

Data pages are actually much easier to manage than code pages — no relocation records needed, no dispatch stubs, just map and access.

User: I just realized: putting vars in the same mem-page as the code, will dilute the R and X memory protection bits...
You could end up executing your data...

GitHub Copilot: Correct observation. Mixed code+data on one page forces you to set R+W+X simultaneously, which means:
- Code is writable (attacker can patch it)
- Data is executable (stack/buffer overflows become code execution)

The protection bits lose their value entirely.

---

## The Separation

The natural fix is what modern systems do — **code and data are separate pages by type:**

| Page type | R | W | X |
|---|---|---|---|
| Code | ✓ | — | ✓ |
| Mutable data (vars, heap) | ✓ | ✓ | — |
| Read-only data (const strings, tables) | ✓ | — | — |
| Stack | ✓ | ✓ | — |

No page ever needs all three bits.

---

## Practical Impact on Your Layout

A typical task now needs more slots:

```
Slot 0–2: code pages        (R+X)
Slot 3:   data page         (R+W)
Slot 4:   stack page        (R+W)
Slot 5:   data window       (R+W, remapped for large datasets)
Slot 6:   shared modules    (R+X, fixed)
Slot 7:   OS kernel         (R+X, fixed)
```

That's tight — 8 slots, 3 for OS/shared, leaving 5 for the task split across code and data.

---

## The Mitigating Factor

Your 64-bank-configuration stack per task is valuable here. A task isn't stuck with one layout — it can rapidly switch between configurations optimized for different phases:

- Config 0: 3 code slots + 2 data slots (normal execution)
- Config 1: 1 code slot + 4 data slots (bulk data processing)
- Config 2: 2 code slots + 1 data + 1 large-data window (bitmap work)

The protection bits stay clean in all configurations. The flexibility comes from the bank switching rather than relaxing protection.

User: Would it help  if I make the memory-page 4k instead? I feel that you have a bit less overhead - at the cost of more book keeping

GitHub Copilot: It doesn't reduce overhead — it trades one problem for another. Whether that trade is worth it depends on which problem is hurting you more.

---

## What 4KB Gives You

**16 slots instead of 8.** That's the only real benefit, but it's a significant one given the slot pressure we kept hitting:

```
Slot 0–1:  OS kernel + NMI handler    (R+X, fixed)
Slot 2:    OS data / kernel stack     (R+W, fixed)
Slot 3–5:  Shared modules             (R+X, fixed)
Slot 6–7:  Task code pages            (R+X, private)
Slot 8–9:  Task code pages            (R+X, private)
Slot 10–11: Task data                 (R+W, private)
Slot 12:   Stack                      (R+W, private)
Slot 13–14: Data windows              (R+W, remapped)
Slot 15:   Free / second task context
```

Clean separation of R+X and R+W pages *without* sacrificing task flexibility.

## What 4KB Costs

- **32MB = 8192 physical pages** to track instead of 4096 — OS page tables double
- **64 bank configs × 16 slots** = more state per task context switch
- **More page binaries** — a 24KB module becomes 6 files instead of 3, 6 reloc tables, 6 headers
- **More slot assignments to manage** for the fixed shared module slots
- **CPLD MMU** needs 16 slot registers instead of 8 — fits in a larger CPLD or requires more careful resource allocation

## The Honest Assessment

The slot count was the binding constraint in every design decision we hit. 4KB pages directly relax that constraint. The bookkeeping cost is real but falls entirely on the OS, not on application programmers.

If you have the CPLD resources for 16 slots, 4KB is probably worth it.

User: I dont see why it would cost more CPLD resources? There will be one bit less the CPLD has to manage (A12) ...

GitHub Copilot: You're right that A12 is now consumed by the slot decoder instead of being routed through as an offset — that saves one signal path. But the dominant cost goes the other way:

**8KB pages:** 8 slot registers × ~16 bits each (12-bit physical page number + R/W/X bits) = ~128 bits of register storage

**4KB pages:** 16 slot registers × ~17 bits each (13-bit physical page number + R/W/X bits) = ~272 bits of register storage

Doubling the slot count more than doubles the register resources needed in the CPLD. The saving of one routed address bit (A12) is real but negligible against that.

The slot decoder logic also grows — a 4-bit decode (16 slots) is roughly twice the logic of a 3-bit decode (8 slots).

Whether it fits depends on your specific CPLD part. What device are you targeting? If you have headroom, 4KB is still worth considering for the slot-count benefits we discussed — just wanted to correct my earlier implication that it was free from the CPLD's perspective.

User: I feel you have a different idea of how the MMU  and CPLD work that I...
The  way I had figured it is that the CPLD manages the upper MMU SRAM address lines. The lower MMU SRAM address lines are connected to the CPU A12-A15 lines.
The CPLD has the remaining MMU SRAM address lines to implement the bank-stack per task and the isolated task stacks. The exact numbers are not relevant. For those lines I need two latches in the CPLD. One that points to the Task/bank for normal program execution and another one  for programming the MMU SRAM value (that is how you change the memory page mapping into the CPU address space).
That's it, no additional register or latches are needed.
You  do need some additional decoding logic, but that is minor. The CPLD is a XC95228XL.

The OS needs to keep  track of some stuff but I was not planning to copy the content of the MMU SRAMs into normal memory. If I want to know how  something is configured, the OS issues an IO operation to fetch the data directly from the MMU SRAM.

Does this help?

GitHub Copilot: Yes, that changes my understanding completely — and makes you correct on the CPLD resource question.

---

## The Actual Architecture

The MMU SRAM is the mapping table. The CPLD just generates its address lines:

```
MMU SRAM address = [ task_latch | bank_latch | CPU_A13-A15 ]
                                                ↑
                                         (3 bits = 8 slots for 8KB)
```

The SRAM output drives the physical RAM's upper address lines. The CPLD holds only two latches — that's it.

---

## Why 4KB Doesn't Cost CPLD Resources

Switching to 4KB pages:
- CPU A12 now routes into the SRAM address instead of through to physical RAM
- The CPLD's two latches are unchanged
- Decoding logic is negligibly different

**The only cost is SRAM size:**

| Page size | Slots | SRAM entries (64 tasks × 64 banks × slots) |
|---|---|---|
| 8KB | 8 | 32,768 |
| 4KB | 16 | 65,536 |

SRAM is cheap. The XC95288XL has plenty of macrocells for the logic. You were right.

---

## What This Also Clarifies

The bank-config switching is essentially free — it's just loading the bank latch with a new value, instantly remapping all 8 (or 16) slots simultaneously. That's a powerful primitive for the cooperative multitasking model you described.

User: With this understanding, going to 4k pages is still a good idea?

GitHub Copilot: Given the actual architecture, the hardware cost is near-zero — just SRAM size doubling, which is cheap. So the question becomes purely a software trade-off.

---

## Reconsidering the Benefit

The main argument for 4KB was slot pressure. But you already have a mitigation: **64 bank configurations per task**. A task isn't stuck with one slot layout — it switches configs for different phases. This largely solves the slot pressure problem without halving page size.

## The Costs Look Bigger Now

- **4KB fills fast for C code.** A single C module with a few functions, local data structures and compiler-generated temporaries can easily exceed 4KB. You'd split modules arbitrarily at page boundaries rather than at logical seams.
- **Twice as many page files** to load, relocate, and track per program
- **OS page tables double** — 8192 physical pages to manage vs 4096
- **More shared module fixed slots** needed — a shared library might now need 2–3 slots instead of 1

## Verdict

With the bank-config stack solving slot pressure, the benefit of 4KB shrinks considerably. The software complexity cost is real and falls on both the OS and the programmer/toolchain.

**Stick with 8KB.** The flexibility you need comes from the 64 bank configs, not from smaller pages.

User: I felt the number of mandatory fixed pages was getting quite large (3 of the 8) and like the dispatch page perhaps not fully utilized. So I though that choosing a smaller page size would leave more free pages.
If I change  the hardware to support 4k pages, I can alwasy go back in managing them as 8k pages in software. So perhaps it is a good idea, still?

GitHub Copilot: That last point is the decisive one: **4KB hardware is a strict superset of 8KB software.**

If you want to treat two adjacent 4KB slots as one 8KB page, just always assign them as a pair in the OS. You lose nothing. You can never do it the other way around — 8KB hardware cannot be subdivided in software.

---

## Your Fixed-Page Argument Is Also Valid

With 8KB and 3 fixed slots:
- 37.5% of CPU address space is permanently consumed by OS/infrastructure
- Each fixed page may only use a fraction of its 8KB

With 4KB:
- You can right-size fixed allocations — OS kernel that only needs 3KB gets one 4KB slot, not a wasteful 8KB slot
- Fixed overhead drops from 3/8 to potentially 4/16 of address space — same absolute bytes, but the remaining 12 dynamic slots vs 5 is a huge difference

---

## Verdict: Change the Hardware to 4KB

- Zero hardware downside (SRAM cost only)
- Strictly more flexible than 8KB
- Fixed-page waste is halved
- Dynamic slots nearly double (5 → 10+)
- Software can always manage pairs as virtual 8KB pages if convenient

Do it now while the hardware is still open. You will not regret having the flexibility later.

User: My thoughts exactly. Thanks!

GitHub Copilot: Good luck with the hardware update. When you get to the CPLD firmware and OS loader design, feel free to continue — there's plenty of interesting detail still to work through (reloc table format, the bank-config switching protocol, shared module registry, etc.).
