User: Having second thoughts on the R bit on my MMU. The MMU manages 4k pages through a mapping stored in SRAM. Besides the mapped  (extra) address lines, I have some bits set aside for access checking by the CPLD. Read, write and execute bits indicate what is allowed for a certain 4k page.
But I was thinking Read is redundant. The Execute bit implies Read and I could think of no case where Read is actually needed.
Do you agree?

GitHub Copilot: I'd partially push back on this.

The key question is: can you express **read-only data** (e.g. constants, shared ROM image, a code page you want readable but not executable) without R?

With only W and X you get four states:

| W | X | Meaning |
|---|---|---------|
| 0 | 0 | ??? — no-access **or** read-only? Ambiguous |
| 1 | 0 | Read-Write data |
| 0 | 1 | Execute (+ implied read) |
| 1 | 1 | RWX |

The W=0, X=0 cell is the problem. You lose the ability to distinguish **no-access** from **read-only data** unless you redefine one of them away entirely.

Two common resolutions:

1. **Redefine W=0,X=0 as "read-only"** and handle no-access via unmapped pages only. Works if your MMU always produces a fault on unmapped accesses and you never need to explicitly guard a *mapped* page against all access.

2. **Keep R.** It costs one SRAM bit per page entry and buys you the clean three-orthogonal-permission model that OS-style memory protection is built on.

There's also a secondary point working **against** your "Execute implies Read" assumption: since the Z80 exposes the **M1** signal, your CPLD can actually distinguish an opcode fetch from a data read. That makes **execute-only** (X=1, R=0) a real, useful state — code that the CPU can run but that a rogue process can't `LD A,(HL)` out byte-by-byte. That's a genuine security boundary if you ever want it.

So: removing R is reasonable if your design never needs read-only data pages as a distinct state, but it's not quite "redundant" — it collapses a useful protection tier.

User: The M1 signal is only active at the start of an instruction, which can have additional read cycles. If the CPLD would see the memory read cycle of the instruction and not see the read-bit it would fault the z80 instruction, falsly.
As for unmapped memory: the mapping is initialized by the os. as I see it now, a memory check/test will determine what pages are backed with actual memory and which pages are not. Only valid memory pages will ever get referenced in the mapping SRAM. The os manages the r/w/x bit when an application is loaded and its memory pages are allocated for their specific purpose.
Does this makes sense?

GitHub Copilot: Yes, both points are correct and they close the gaps I raised.

**On M1**: You're right, and this is a fundamental Z80 constraint. M1 only covers the opcode fetch. Instructions with immediate operands or memory reads (`LD A,(nn)`, `LD HL,(nn)`, etc.) generate additional read cycles without M1. An execute-only page would fault on those. So X does imply R in practice — execute-only is not a usable protection state on the Z80.

**On unmapped pages**: Your model is clean. The mapping SRAM only ever contains entries for physically-backed pages the OS has verified exist. "No access" is simply the absence of a valid mapping entry, not a bit combination within an entry. The CPLD faults on any access to an unmapped page regardless of bits.

That resolves the W=0, X=0 ambiguity neatly:

| W | X | Meaning |
|---|---|---------|
| 0 | 0 | Read-only (mapped, but no write or execute) |
| 1 | 0 | Read-Write data |
| 0 | 1 | Execute (code page) |
| 1 | 1 | Read-Write-Execute |

No-access = no valid mapping entry, handled upstream.

So yes — dropping R is sound given your architecture. The OS controls what gets mapped, the CPLD guards R/W/X on mapped pages, and the Z80's M1 limitation makes execute-only impractical anyway.

User: I thought perhaps I could use the R bit as a marker that the page is reserved for the os, but I could not figure out how to enforce that. When an application (from a page without the os-bit on) accesses a page with the os-bit on, the CPLD should detect that an generate a fault. But I fear the logic for this is to complex for the CPLD - that already has to do quite a bit...
What do you think?

GitHub Copilot: The concept is sound, but the complexity is less in the CPLD logic and more in the **mode-switching mechanism**.

The CPLD logic itself is trivial:

```
fault = (supervisor_mode == 0) AND (target_page_os_bit == 1)
```

One flip-flop for `supervisor_mode`, one extra term in your fault condition. That's not expensive.

The hard part is **securely controlling that flip-flop**:

- **Setting it (entering supervisor):** Easiest to tie to reset and to the interrupt acknowledge cycle. On Z80, /IORQ + /M1 low together signal an interrupt acknowledgment — the CPLD can detect that and set `supervisor_mode = 1`. NMI is even simpler to detect.
- **Clearing it (dropping to user mode):** A dedicated I/O write to a specific port, only honoured when `supervisor_mode = 1` (so the application can't do it itself).
- **Returning to user mode after a syscall:** Requires the OS to explicitly write that port before returning. RETI alone won't do it — the CPLD can't reliably detect RETI from the outside.

The real risk is a **subtle design error** in the mode transition logic that lets an application escape to supervisor mode. That's a security correctness problem, not a gate-count problem.

**Practical alternative worth considering:** rather than the OS bit approach, simply don't map OS pages into the application's logical address space at all. If the OS lives in pages that are only mapped when `supervisor_mode = 1` (or mapped to a fault handler page in user mode), you get the same protection without per-page OS bits. The MMU mapping itself becomes the enforcement mechanism, which you already have.

User: You sound like you have a PC's virtual memory system in mind - this is very different...?
Why cant the CPLD not detect an RETI instructions - that is currently required for its interrupt controller implementation.
There have to be OS pages in all application address spaces, to access os functionality. I was just trying to prohibit an application from reading OS's data for instance.

GitHub Copilot: Fair corrections on all three points.

**RETI detection:** You're right, I contradicted myself. The CPLD already watches the data bus during M1 cycles to detect the `ED 4D` sequence — that's the standard Z80 daisy-chain mechanism. If it already tracks that, clearing `supervisor_mode` on RETI costs nothing extra. So the mode-switching becomes very clean: set on interrupt acknowledge, clear on RETI — both already handled.

**Memory model:** Yes, I was over-abstracting. On a Z80 system OS pages have to be present in the application's address space. There's no ring-switch page-table swap like on a PC.

**OS bit as page protection:** Given the corrected RETI picture, the whole scheme is actually simpler than I suggested. You'd have:

- `supervisor_mode` flip-flop in the CPLD, set on /IORQ+/M1 (interrupt ack), cleared on RETI
- OS bit in the page entry
- Fault condition: `supervisor_mode == 0 AND page_os_bit == 1 AND (read OR write)`

OS code pages would have OS=1, X=1 — applications can call into them (jump to them), but since they're also OS=1, a user-mode *data read* of that page would fault. That's exactly the protection you want.

The only remaining question is syscall entry — if applications call OS via RST or a jump rather than through an interrupt, `supervisor_mode` won't be set. How does your current syscall mechanism work?

User: I dont have one yet - I am just starting to  think on this subject. But the  RST instruction is an obvious choice.
Setting the supervisor mode through an IO operation is not a guarentee that an application wont do that too.,..

GitHub Copilot: Exactly the right concern — an I/O port to set supervisor mode is no protection at all if user code can write it freely.

The solution is to **never use software-initiated I/O to set supervisor mode**. Only let the CPLD set it in response to signals that hardware generates and software cannot forge:

- **Interrupt acknowledge** (`/IORQ` + `M1` low together) — the CPU asserts this, not software
- **RST opcode detection** — the CPLD watches the data bus during M1 and recognises the `11xxx111` pattern

For the RST syscall path specifically:
- CPLD sees RST opcode fetched from a page with OS_bit=0 (user code making a call)
- CPLD sets `supervisor_mode = 1` at that point, before execution reaches the vector
- RST vectors (fixed addresses 0x00–0x38) live in OS pages
- OS handler runs in supervisor mode
- RETI clears `supervisor_mode` and returns to user mode

An application cannot forge this because it cannot fake an M1 cycle with an RST opcode on the data bus — that's a hardware event. The I/O port approach is simply not needed and should be dropped.

One edge case to think about: what if user code *contains* an RST instruction for its own internal use, jumping to a user-space routine that happens to be at 0x08 etc.? That breaks the model since those vectors must be OS-only. In practice this means **RST is reserved for syscalls** — user code cannot use it freely. That's a constraint worth documenting in your ABI.

User: Cant happen, the 0-page will always be an OS-page with RSTs and IM2  vectors and MMU routines

GitHub Copilot: Right, that closes the edge case cleanly. If page 0 is permanently OS-mapped and OS-bit protected, then:

- RST vectors always land in OS space — guaranteed by the mapping, not by convention
- User code physically cannot occupy that page, so there's nothing to "fake"
- IM2 vectors likewise always resolve through OS-controlled addresses

The whole scheme then holds without any additional constraints on user code. RST as syscall entry works correctly as a hardware-enforced supervisor transition.

User: How do you reset supervisor mode from a RST call? RETI?

GitHub Copilot: Yes, but with a wrinkle.

RST does **not** disable interrupts (unlike a hardware interrupt which clears IFF1). RETI does two things on Z80:

1. Pops the return address (like RET)
2. Signals the daisy-chain interrupt controller and restores IFF1 from IFF2

Step 2 is the problem. If an interrupt occurs *during* the RST syscall handler, IFF2 gets modified, and RETI will restore a wrong IFF1 value. It may also send a spurious completion signal to the interrupt controller.

Practical options:

- **Use RETI anyway, as a convention** — if your OS keeps the RST handlers short and the daisy-chain controller tolerates the signal, it often just works. Worth considering if your design is simple enough.

- **Dedicated I/O write to clear supervisor mode, only honoured from OS pages** — this is safe because user code can't reach it without already being in supervisor mode (it can't forge an OS-page execution context). The CPLD checks: `supervisor_mode == 1` before honouring the clear. This decouples syscall exit from RETI entirely.

- **Track entry reason in the CPLD** — one extra bit: "entered via INT or RST". Clear on RETI only if entered via INT; clear on RET if entered via RST. But detecting RET vs RETI from the bus is doable (`C9` vs `ED 4D`), so this is feasible.

The second option (supervised I/O port) is probably the cleanest separation given you're already thinking about the CPLD doing this work.

User: If an INT occurs during a RST call, that handler has finished (RETI) beforee the RST returns with RETI. What happens when you call RETI 'twice'?

GitHub Copilot: Good question — it's actually fine in that specific nesting order.

Walk through the state:

1. User code runs RST — IFF1/IFF2 **unchanged** (RST doesn't touch them). Supervisor mode set by CPLD.
2. Interrupt fires inside RST handler — Z80 saves IFF1→IFF2, clears IFF1. IFF2=1, IFF1=0.
3. ISR runs, **first RETI** — IFF1 restored from IFF2 back to 1. Daisy-chain notified. ISR done.
4. RST handler resumes with IFF1=1, IFF2=1.
5. RST handler executes **second RETI** — IFF1 = IFF2 = 1, no change. Stack pop correct. Daisy-chain notified again.

Step 5 sends a second daisy-chain RETI signal, but at that point no device is holding IEO low (the ISR already completed), so the signal is a no-op. Nothing in the daisy chain responds to it.

So **RETI as RST return works correctly even with nested interrupts**, in this nesting order. The IFF state ends up right, the stack is right, and the spurious daisy-chain signal is harmless.

The only real issue remaining is the supervisor mode flip-flop — your CPLD needs to track whether it was set by an INT or an RST, so the second RETI clears supervisor mode rather than the first one. Otherwise the ISR's RETI would drop back to user mode while still inside the RST handler.

User: How would the CPLD check if a `LD (nn), HL` is writing to a page with the W-bit set? Obviously the current page has the X-bit on for executing code.

GitHub Copilot: This is actually the natural, simple case — the CPLD doesn't need to know which instruction is executing at all.

Every bus cycle, the CPLD does the same thing:

1. Address bus presents the **target address** (`nn` during the write cycle)
2. CPLD uses the upper 4 bits (A15:A12) to look up that page's entry in the mapping SRAM
3. Returns the physical page bits **and** the W/X/OS bits for *that* page
4. CPLD checks: cycle is a write (`/WR` low) → is W-bit set on the target page? No → fault

The code page's X-bit is only checked during the opcode fetch cycles, when PC is on the address bus. By the time the write cycle happens, the target address `nn` is on the bus — so the CPLD is automatically looking at the *destination* page's attributes, not the source.

The CPLD never needs to decode instructions. It just responds to bus cycles:

| Bus cycle | Address on bus | Check |
|---|---|---|
| M1 (opcode fetch) | PC | X-bit of code page |
| Memory read | operand/pointer address | (R-bit if kept) |
| Memory write | destination address | W-bit of target page |

The instruction decoder is the CPU — the CPLD only sees bus cycles.
