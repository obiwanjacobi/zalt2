User: how would you implement cooperative multi tasking  on Z80?

GitHub Copilot: ## Cooperative Multitasking on Z80

The core idea: each task has its **own stack**. "Yielding" means saving all registers onto the current stack, swapping `SP` to another task's stack, then restoring registers and `RET`-ing into that task.

---

### Task Control Block (TCB)

```asm
; TCB layout (in RAM)
TCB_SP:     dw 0    ; saved stack pointer
TCB_STATUS: db 0    ; 0=ready, 1=waiting
TCB_NEXT:   dw 0    ; pointer to next TCB (circular linked list)
```

---

### Context Switch (YIELD)

The trick: when a task calls `YIELD`, its return address is already on the stack. Save all other registers, swap `SP`, restore, then `RET` resumes the new task exactly where it last yielded.

```asm
YIELD:
    ; --- Save current task context ---
    push af
    push bc
    push de
    push hl
    push ix
    push iy
    ex   af, af'        ; swap to alternate register set
    exx
    push af
    push bc
    push de
    push hl
    exx
    ex   af, af'

    ; Save SP into current TCB
    ld   hl, (CURRENT_TASK)   ; HL = pointer to current TCB
    ld   (hl), sp             ; TCB_SP = SP  (lo byte)
    inc  hl
    ld   a, sp >> 8           ; not valid Z80 — see note below
    ld   (hl), a

    ; --- Run scheduler: advance CURRENT_TASK ---
    call SCHEDULE

    ; Restore SP from new task's TCB
    ld   hl, (CURRENT_TASK)
    ld   sp, (hl)             ; SP = new task's saved SP

    ; --- Restore new task context ---
    exx
    ex   af, af'
    pop  hl
    pop  de
    pop  bc
    pop  af
    exx
    ex   af, af'
    pop  iy
    pop  ix
    pop  hl
    pop  de
    pop  bc
    pop  af

    ret                       ; PC = address where new task called YIELD
```

> **Note on saving SP:** Z80 can't `push sp` directly. Use `ld (addr), sp` via a 16-bit store: store to a temp word, then copy to TCB. A clean pattern:
> ```asm
> ld   (TEMP_SP), sp
> ld   hl, (TEMP_SP)
> ld   (TCB_SP_FIELD), hl
> ```

---

### Round-Robin Scheduler

```asm
SCHEDULE:
    ld   hl, (CURRENT_TASK)
SCHED_LOOP:
    ld   hl, (hl + 3)         ; TCB_NEXT offset = 3
    ld   a,  (hl + 2)         ; TCB_STATUS
    or   a
    jr   z, SCHED_DONE        ; status == 0 (ready) → use it
    jr   SCHED_LOOP           ; skip waiting tasks
SCHED_DONE:
    ld   (CURRENT_TASK), hl
    ret
```

*(Use actual offsets based on your TCB layout.)*

---

### Task Initialization

When you create a task, **fake a YIELD stack frame** so the first context switch drops it at its entry point:

```asm
; Call with: HL = top of task stack, DE = task entry point
; Returns:   HL = initial SP to store in TCB
INIT_TASK_STACK:
    dec  hl
    ld   (hl), d        ; push task entry address (hi)
    dec  hl
    ld   (hl), e        ; push task entry address (lo)

    ; Push 10 zero register pairs (AF, BC, DE, HL, IX, IY, AF', BC', DE', HL')
    ld   b, 20          ; 20 bytes = 10 pairs
    xor  a
INIT_LOOP:
    dec  hl
    ld   (hl), a
    djnz INIT_LOOP

    ; HL now = initial SP for this task
    ret
```

---

### Stack Layout at Switch Point

```
High address  ┌─────────────┐
              │  return PC  │  ← pushed by CALL YIELD (or task entry)
              │  AF         │
              │  BC         │
              │  DE         │
              │  HL         │
              │  IX         │
              │  IY         │
              │  AF'        │
              │  BC'        │
              │  DE'        │
              │  HL'        │  ← SP points here after saving
Low address   └─────────────┘
```

---

### Practical Notes for Zalt

- **Stack size per task**: 128–256 bytes is usually enough for Z80 tasks without deep call chains.
- **IFF (interrupt flip-flops)**: If you use interrupts, decide whether to save/restore interrupt enable state per-task (`DI`/`EI` around the SP swap is the safest approach).
- **I and R registers**: Typically don't need saving — `I` is set once for interrupt vectors, `R` is the refresh counter.
- **Minimum yield point**: Tasks don't need a dedicated `CALL YIELD`; any subroutine call can be the yield trigger (useful for blocking I/O wrappers).

The entire switcher is ~30 instructions, making it very practical even on a 4 MHz Z80.

User: what about using co-routines? The program is one big loop and statemachine.

GitHub Copilot: ## Coroutines on Z80 — Replacing State Machines

The key insight: a coroutine's **saved PC is its entire state**. Instead of a state variable tracking where you are in a protocol, you just `YIELD` mid-execution and resume exactly there.

---

### Comparison: State Machine vs Coroutine

**State machine (current approach):**
```asm
; Ugly — must remember position with explicit state variable
SERIAL_TASK:
    ld   a, (serial_state)
    or   a
    jr   z, .waiting_for_header

    dec  a
    jr   z, .waiting_for_length
    ; ...

.waiting_for_header:
    call SERIAL_RX_READY
    ret  z
    call SERIAL_READ            ; read start byte
    cp   0xA5
    ret  nz
    ld   a, 1
    ld   (serial_state), a
    ret
```

**Coroutine (natural sequential code):**
```asm
; Clean — code just "waits" naturally
SERIAL_TASK:
.wait_header:
    call SERIAL_RX_READY
    jr   z, .yield_and_retry_header
    call SERIAL_READ
    cp   0xA5
    jr   nz, .wait_header     ; wrong byte, keep waiting

.wait_length:                  ; code flows naturally, no state var!
    call SERIAL_RX_READY
    jr   z, .yield_and_retry_length
    call SERIAL_READ
    ld   (packet_len), a

    ; ... process packet, then loop back
    jr   SERIAL_TASK

.yield_and_retry_header:
    call YIELD
    jr   .wait_header

.yield_and_retry_length:
    call YIELD
    jr   .wait_length
```

---

### Minimal Coroutine Engine

```asm
; --- Coroutine descriptors (just a saved PC each) ---
CORO_MAIN_PC:   dw 0
CORO_SERIAL_PC: dw 0
CORO_VIDEO_PC:  dw 0

; Round-robin table — pointers to descriptors, terminated by 0
CORO_TABLE:
    dw CORO_MAIN_PC
    dw CORO_SERIAL_PC
    dw CORO_VIDEO_PC
    dw 0                    ; sentinel

CURRENT_CORO:   dw CORO_TABLE   ; points at current slot in CORO_TABLE

; -------------------------------------------------------
; YIELD — suspend current coroutine, resume next
; Destroys AF, HL. Caller saves everything else.
; -------------------------------------------------------
YIELD:
    pop  hl                     ; HL = our resume address (return from CALL YIELD)

    ; Save our resume address into our descriptor
    ld   de, (CURRENT_CORO)     ; DE -> slot in CORO_TABLE
    ld   bc, (de)               ; BC = address of our PC descriptor
    ld   (bc), hl               ; store resume PC

    ; Advance to next slot
    inc  de
    inc  de
    ld   hl, (de)               ; peek at next slot value
    ld   a, h
    or   l
    jr   nz, .not_wrap
    ld   de, CORO_TABLE         ; wrap around to start
.not_wrap:
    ld   (CURRENT_CORO), de     ; update current

    ; Jump to next coroutine's saved PC
    ld   de, (de)               ; DE = address of next descriptor
    ld   hl, (de)               ; HL = saved PC of next coroutine
    jp   (hl)
```

---

### Initialization

```asm
START:
    ; Point each descriptor at the coroutine's entry point
    ld   hl, MAIN_TASK
    ld   (CORO_MAIN_PC), hl

    ld   hl, SERIAL_TASK
    ld   (CORO_SERIAL_PC), hl

    ld   hl, VIDEO_TASK
    ld   (CORO_VIDEO_PC), hl

    ; Jump into the first coroutine directly
    jp   MAIN_TASK
```

---

### Execution Flow

```
MAIN_TASK  ──YIELD──►  SERIAL_TASK  ──YIELD──►  VIDEO_TASK  ──YIELD──┐
    ▲                                                                   │
    └───────────────────────────────────────────────────────────────────┘
```

Each `YIELD` costs only ~20 cycles — essentially free on a 4 MHz Z80.

---

### Practical Tips for Your Loop

- **No registers are saved** — keep coroutines independent, or push/pop what you need around `YIELD`.
- **Blocking I/O becomes trivial** — a `WAIT_BYTE` wrapper just loops `call SERIAL_RX_READY` / `call YIELD` until data arrives. All callers look synchronous.
- **Skip yielding when busy** — if a task finishes work quickly it can call `YIELD` less often, naturally prioritizing it. No scheduler complexity needed.
- **Coroutines can call subroutines freely** — only the outermost `YIELD` call matters; nested calls work normally.

User: I think there is a bug in the chat display view? I saw a lot of jittering ui and a couple of empty headings...? (see active doc)

GitHub Copilot: That's a VS Code chat UI rendering issue, not something in your code. Looking at the attachment, the response rendered the headings but dropped the code blocks beneath **Minimal Coroutine Engine**, **Initialization**, and **Execution Flow**.

This is a known occasional glitch in the VS Code chat panel — typically triggered by long responses with many fenced code blocks, sometimes caused by streaming interruptions or UI re-renders mid-response.

**Workarounds:**
- Scroll up and click **Rerun** (↺) on that message to regenerate it
- Or just ask me to re-post only the missing sections

Want me to repost the coroutine engine + initialization + flow diagram code?

User: yes (I dont see the rerun button)

GitHub Copilot: ### Minimal Coroutine Engine

```asm
; --- Coroutine descriptors (just a saved PC each) ---
CORO_MAIN_PC:   dw 0
CORO_SERIAL_PC: dw 0
CORO_VIDEO_PC:  dw 0

; Round-robin table — pointers to descriptors, terminated by 0
CORO_TABLE:
    dw CORO_MAIN_PC
    dw CORO_SERIAL_PC
    dw CORO_VIDEO_PC
    dw 0                    ; sentinel

CURRENT_CORO:   dw CORO_TABLE   ; points at current slot in CORO_TABLE

; -------------------------------------------------------
; YIELD — suspend current coroutine, resume next
; Destroys AF, HL. Caller saves everything else.
; -------------------------------------------------------
YIELD:
    pop  hl                     ; HL = our resume address (return from CALL YIELD)

    ; Save our resume address into our descriptor
    ld   de, (CURRENT_CORO)     ; DE -> slot in CORO_TABLE
    ld   bc, (de)               ; BC = address of our PC descriptor
    ld   (bc), hl               ; store resume PC

    ; Advance to next slot
    inc  de
    inc  de
    ld   hl, (de)               ; peek at next slot value
    ld   a, h
    or   l
    jr   nz, .not_wrap
    ld   de, CORO_TABLE         ; wrap around to start
.not_wrap:
    ld   (CURRENT_CORO), de     ; update current

    ; Jump to next coroutine's saved PC
    ld   de, (de)               ; DE = address of next descriptor
    ld   hl, (de)               ; HL = saved PC of next coroutine
    jp   (hl)
```

---

### Initialization

```asm
START:
    ; Point each descriptor at the coroutine's entry point
    ld   hl, MAIN_TASK
    ld   (CORO_MAIN_PC), hl

    ld   hl, SERIAL_TASK
    ld   (CORO_SERIAL_PC), hl

    ld   hl, VIDEO_TASK
    ld   (CORO_VIDEO_PC), hl

    ; Jump into the first coroutine directly
    jp   MAIN_TASK
```

---

### Execution Flow

```
MAIN_TASK  ──YIELD──►  SERIAL_TASK  ──YIELD──►  VIDEO_TASK  ──YIELD──┐
    ▲                                                                   │
    └───────────────────────────────────────────────────────────────────┘
```

Each `YIELD` costs only ~20 cycles — essentially free on a 4 MHz Z80.

User: still nothing...

GitHub Copilot: This is definitely a VS Code chat rendering bug on your end. Let me put it in a file instead so you can read it directly. 

Created [](file:///c%3A/My/MyProjects/Zalt/Source2/src/coroutines.asm)

Created src/coroutines.asm — you can read it there without the chat rendering issues.

Made changes.

User: I had something cooked up in C. What do you think?

GitHub Copilot: Read [](file:///c%3A/My/MyProjects/Zalt/Source/z88dk_target/_tests.unit/sys/AsyncTests.c#1-1), lines 1 to 100

Read [](file:///c%3A/My/MyProjects/Zalt/Source/z88dk_target/_tests.unit/sys/AsyncTests.c#100-100), lines 100 to 105

Searched for files matching `**/Async.h`, 1 match

Read [](file:///c%3A/My/MyProjects/Zalt/Source/z88dk_target/src/sys/Async.h)

Searched for files matching `**/Async.c`, 1 match

Read [](file:///c%3A/My/MyProjects/Zalt/Source/z88dk_target/src/sys/Async.c)

Searched for text `Async_Function|Async_WaitUntil|Async_YieldUntil|Async_EndFn|Async_Result|asyncResult_` (`**/Sys.h`), 20 results

Read [](file:///c%3A/My/MyProjects/Zalt/Source/z88dk_target/src/sys/Sys.h#80-80), lines 80 to 200

This is a classic **Protothreads / Duff's Device** pattern — and it's very well done.

The core trick is the `switch(async->State)` combined with `__LINE__` as the state value:

```c
#define Async_WaitUntil(expression)
    async->State = __LINE__; case __LINE__:   // saves position AND re-entry label
    if (!(expression)) { return Pending; }    // jump back here next call
```

On re-entry, `switch` jumps directly to `case __LINE__:` — **the saved PC is the line number itself.** No assembly required.

**What's particularly good:**

- The `WaitUntil` vs `YieldUntil` distinction is thoughtful — `WaitUntil` evaluates the condition before yielding (free pass if already true), `YieldUntil` always suspends at least once. The `_yield_` flag trick for that is clever.
- `Async_FunctionWithParams` makes it composable — one async fn can call another passing context.
- Tests verify both the off-by-one count difference between the two and the `IsPending`/`IsCompleted` API. Solid coverage.

**One caveat to be aware of** (you probably already know this): **local variables inside an `Async_Function` don't survive across a yield** — the C stack frame is gone. Anything that needs to persist across a `WaitUntil`/`Yield` must live in the `AsyncThis` struct or as a `static`/global. That's the fundamental tradeoff of this pattern vs. full coroutines with separate stacks.

Overall — clean, zero-overhead for the Z80 (no `malloc`, no stack swapping), and the macro API reads almost like native `async/await`. Nice work.

User: How do you see an async data transfer (say a file on HD)? Something like a stream that one end writes to and the other end reads from - but very lightweight and efficient. (in C89)

GitHub Copilot: ## Async Stream — Ring Buffer + EOF Signal

The natural fit: a **circular ring buffer** where writer and reader are independent async functions. Both sides just `Async_WaitUntil` their condition, and the buffer decouples their speeds.

Key Z80 efficiency decisions:
- Size is **power of 2** → use `& mask` instead of `% size` (no software divide)
- External buffer → stream struct is only **6 bytes**, buffer lives wherever you want
- No dynamic allocation, no function pointers

---

### Stream.h

```c
#ifndef __STREAM_H__
#define __STREAM_H__

#include "Sys.h"

typedef struct _stream {
    uint8_t *buf;
    uint8_t  mask;    /* = size - 1  (size MUST be power of 2) */
    uint8_t  head;    /* write index */
    uint8_t  tail;    /* read index  */
    uint8_t  count;
    bool_t   closed;  /* writer signals no more data */
} Stream;

void    Stream_Construct(Stream *s, uint8_t *buf, uint8_t size);

/* Writer side */
bool_t  Stream_CanWrite(Stream *s);
void    Stream_Write(Stream *s, uint8_t byte);
void    Stream_Close(Stream *s);      /* signal EOF */

/* Reader side */
bool_t  Stream_CanRead(Stream *s);
uint8_t Stream_Read(Stream *s);
bool_t  Stream_IsDone(Stream *s);     /* closed AND buffer drained */

#endif
```

---

### Stream.c

```c
#include "Stream.h"

void Stream_Construct(Stream *s, uint8_t *buf, uint8_t size)
{
    s->buf    = buf;
    s->mask   = size - 1;
    s->head   = 0;
    s->tail   = 0;
    s->count  = 0;
    s->closed = false;
}

bool_t Stream_CanWrite(Stream *s)
{
    return s->count <= s->mask;   /* count < size */
}

void Stream_Write(Stream *s, uint8_t byte)
{
    s->buf[s->head] = byte;
    s->head = (s->head + 1) & s->mask;
    s->count++;
}

void Stream_Close(Stream *s)
{
    s->closed = true;
}

bool_t Stream_CanRead(Stream *s)
{
    return s->count > 0;
}

uint8_t Stream_Read(Stream *s)
{
    uint8_t byte = s->buf[s->tail];
    s->tail = (s->tail + 1) & s->mask;
    s->count--;
    return byte;
}

bool_t Stream_IsDone(Stream *s)
{
    return s->closed && s->count == 0;
}
```

---

### Usage — HD transfer example

```c
static uint8_t   _hd_buf[32];
static Stream    _hd_stream;

/* --- Producer: HD driver reads sectors, writes to stream --- */
Async_FunctionWithParams(HdRead, uint16_t sector)
{
    static uint8_t  byte;
    static uint16_t remaining;

    remaining = 512;              /* one sector */
    Async_WaitUntil(Hd_IsReady());

    Hd_StartRead(sector);

    while (remaining > 0)
    {
        Async_WaitUntil(Hd_ByteReady());
        byte = Hd_ReadByte();

        Async_WaitUntil(Stream_CanWrite(&_hd_stream));
        Stream_Write(&_hd_stream, byte);
        remaining--;
    }

    Stream_Close(&_hd_stream);
}
Async_EndFn();

/* --- Consumer: receives bytes, does whatever --- */
Async_Function(FileConsumer)
{
    static uint8_t byte;

    Async_WaitUntil(Stream_CanRead(&_hd_stream) || Stream_IsDone(&_hd_stream));

    while (Stream_CanRead(&_hd_stream))
    {
        byte = Stream_Read(&_hd_stream);
        /* process byte */
    }

    if (Stream_IsDone(&_hd_stream))
        Async_Return();
}
Async_EndFn();

/* --- Main loop --- */
void Main_Loop(void)
{
    Stream_Construct(&_hd_stream, _hd_buf, 32);

    for (;;)
    {
        HdRead(&hd_async, 0);
        FileConsumer(&consumer_async);
        /* other tasks... */
    }
}
```

---

### Data flow

```
HD hardware          HdRead async          Stream buffer          FileConsumer async
     │                    │                [## ## ## ##..........]      │
     │──ByteReady()───►   │──Stream_Write()──────────────────►          │
     │                    │                                   Stream_CanRead()──►│
     │                    │                                              │──Stream_Read()
     │                    │──Stream_Close()──► closed=true               │
     │                    │                                   Stream_IsDone()──► done
```

The buffer absorbs speed mismatches — the HD drvier and consumer run at their own pace across yields. 32 bytes buffer costs 38 bytes RAM total (32 buf + 6 struct).

User: Could generate the Stream.h/c code into files as well as the example? I am not seeing the content in the chat window again...

GitHub Copilot: Created 3 todos

Created [](file:///c%3A/My/MyProjects/Zalt/Source2/src/sys/Stream.h)

Starting: *Create Stream.c* (2/3)

Created [](file:///c%3A/My/MyProjects/Zalt/Source2/src/sys/Stream.c)

Starting: *Create Stream example file* (3/3)

Created [](file:///c%3A/My/MyProjects/Zalt/Source2/src/sys/StreamExample.c)

Completed: *Create Stream example file* (3/3)

Three files created:

- src/sys/Stream.h — struct definition and API declarations
- src/sys/Stream.c — implementation
- src/sys/StreamExample.c — HD transfer example with producer/consumer

Made changes.

User: You said something about that local vars do not survive co-routine reentry.
That would mean 'remaining' will be 512 on every (re)entry...?

GitHub Copilot: Good catch on the concern — but the code is actually correct, for two reasons working together:

**1. `static` keeps the value alive in memory**

A non-static local would be on the C stack frame, which is gone between calls. `static` makes it a global in disguise — it lives at a fixed address. That's why the example uses `static uint16_t remaining`.

**2. The Duff's device switch skips the assignment on re-entry**

`remaining = 512` sits at `case 0:` (the function start). On re-entry, `async->State` holds the `__LINE__` of the last `Async_WaitUntil` inside the `while` loop, so `switch` jumps directly there — completely skipping `remaining = 512`:

```c
switch (async->State)
{
case 0:
    remaining = 512;          // ← only reached on fresh start (State==0)
    Async_WaitUntil(...);     // sets State = __LINE__, returns if not ready
    Hd_StartRead(sector);
    while (remaining > 0)
    {
        Async_WaitUntil(...); // re-entry jumps HERE, remaining intact
        ...
        remaining--;
    }
}
```

So the two `static` variables in the example are intentional and necessary — it's the standard pattern for persisting loop state across yields in this style of async. Any variable that must survive a `WaitUntil`/`Yield` **must** be `static` (or live in the `AsyncThis` struct / a global).

User: Perhaps having a way to put them on the AsyncThis ("derived") structure would be cleaner...?

GitHub Copilot: Yes — and it solves a real problem too. `static` locals are **shared across all instances** of the function. If you ever called `HdRead` twice concurrently (two drives, two sectors), they'd clobber each other's `remaining`. A derived struct gives each instance its own state.

The pattern: embed `AsyncThis` as the **first member** (C guarantees pointer cast safety), then cast `async` inside the function body. 

Replacing 61 lines with 78 lines in [](file:///c%3A/My/MyProjects/Zalt/Source2/src/sys/StreamExample.c)


```

```
Now update the `Main_Loop` calls to cast to `AsyncThis*`: 

Replacing 7 lines with 7 lines in [](file:///c%3A/My/MyProjects/Zalt/Source2/src/sys/StreamExample.c)


```

```
Also update `Async_Construct` calls: 

Replacing 3 lines with 3 lines in [](file:///c%3A/My/MyProjects/Zalt/Source2/src/sys/StreamExample.c)


```

```
The key points of this pattern:

- **`AsyncThis _async` must be the first member** — C guarantees `(AsyncThis*)&derived` gives the same address, so the cast is safe with no UB.
- **Per-instance state** — you could now have two concurrent `HdRead` tasks (e.g. two drives) using separate `HdReadThis` instances without interference.
- **`Async_Construct` still works** — just cast to `(AsyncThis*)` at the call site; it only touches `State` and `Result` which are at offset 0.
- **No macros needed** — the `(HdReadThis *)async` cast inside the function body is straightforward C89.

Made changes.

User: yes, exactly. very nice

GitHub Copilot: The pattern scales well — when you add more async functions, the struct acts as a natural home for all the "local" context that function needs, almost like a lightweight coroutine object. Makes the ownership of state very clear too.