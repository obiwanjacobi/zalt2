User: Timer 2 of the ATmega1284 can be used as realtime clock (RTC). It takes a 32.768kHz cristal (TOSC1+TOSC2).
Is there any info on how to set it up further  in order to get a date and time out  of it?

GitHub Copilot: Read [](file:///c%3A/My/MyProjects/zalt2/Source/MCU/src/main.cpp)

Timer 2 on the ATmega1284P in **asynchronous mode** is the standard AVR approach to a software RTC. Here's the full picture:

---

## How it works

The 32.768 kHz crystal on **TOSC1/TOSC2** drives Timer 2 independently from the main clock. With a prescaler of 128, you get exactly **1 overflow per second** ($32768 / 128 / 256 = 1\,\text{Hz}$). You increment a time struct in the ISR.

---

## Setup

```cpp
#include <avr/io.h>
#include <avr/interrupt.h>
#include <stdint.h>

typedef struct {
    uint8_t sec;
    uint8_t min;
    uint8_t hour;
    uint8_t day;
    uint8_t month;
    uint16_t year;
} rtc_t;

volatile rtc_t rtc = {0, 0, 0, 1, 1, 2026};

// Days per month (non-leap)
static const uint8_t dom[] = {31,28,31,30,31,30,31,31,30,31,30,31};

static uint8_t is_leap(uint16_t y) {
    return (y % 4 == 0 && (y % 100 != 0 || y % 400 == 0));
}

void rtc_init(void) {
    // 1. Select asynchronous clock source (external crystal on TOSC1/2)
    ASSR = (1 << AS2);

    // 2. Set prescaler 128 → 1 overflow/sec at 32768 Hz
    TCCR2A = 0;
    TCCR2B = (1 << CS22) | (1 << CS20);  // prescaler = 128

    // 3. Wait for registers to synchronize across clock domains
    while (ASSR & ((1 << TCN2UB) | (1 << TCR2BUB) | (1 << TCR2AUB)));

    // 4. Clear pending interrupt flag, then enable overflow interrupt
    TIFR2  = (1 << TOV2);
    TIMSK2 = (1 << TOIE2);
}

ISR(TIMER2_OVF_vect) {
    if (++rtc.sec < 60) return;
    rtc.sec = 0;
    if (++rtc.min < 60) return;
    rtc.min = 0;
    if (++rtc.hour < 24) return;
    rtc.hour = 0;

    uint8_t days = dom[rtc.month - 1];
    if (rtc.month == 2 && is_leap(rtc.year)) days = 29;

    if (++rtc.day <= days) return;
    rtc.day = 1;
    if (++rtc.month <= 12) return;
    rtc.month = 1;
    ++rtc.year;
}
```

---

## Key points

| Topic | Detail |
|---|---|
| **AS2 bit** | Must be set in `ASSR` before touching any Timer 2 register |
| **Sync wait** | After writing TCCR2x/TCNT2/OCR2x, poll `ASSR` update-busy bits — the registers cross clock domains |
| **Prescaler 128** | CS22+CS20 → 32768/128/256 = exactly 1 Hz overflow |
| **Power saving** | Timer 2 async keeps ticking in `SLEEP_MODE_PWR_SAVE` — ideal for low-power RTC |
| **Reading `rtc`** | Disable interrupts briefly (`cli()`/`sei()`) when reading multi-byte struct from main code to avoid torn reads |

---

## Sleep mode integration (optional, power-saving)

```cpp
#include <avr/sleep.h>

void sleep_1s(void) {
    set_sleep_mode(SLEEP_MODE_PWR_SAVE);
    sleep_enable();
    sei();
    sleep_cpu();      // wakes on Timer2 overflow (every 1s)
    sleep_disable();
}
```

This lets the MCU draw only a few µA between ticks, with Timer 2 async running entirely off the crystal.

User: how is 32.768kHz divided by 128, 32768 Hz?

GitHub Copilot: I made a typo in the comment. The full chain is:

$$\frac{32768\,\text{Hz}}{128\,\text{(prescaler)}} = 256\,\text{Hz} \quad \xrightarrow{\div\,256\,\text{(8-bit overflow)}} \quad 1\,\text{Hz}$$

- **÷ 128** (prescaler): timer clock = 256 Hz
- **÷ 256** (8-bit counter wraps 0→255→overflow): 1 overflow per second

The comment in my previous code should have read `// prescaler = 128 → 256 Hz timer clock → 1 overflow/sec`.

User: can we get 10th of seconds? (10Hz)?

GitHub Copilot: **No — exact 10Hz is not achievable.** 

32768 = 2¹⁵, a pure power of 2. Since 10 = 2 × **5**, and 5 is never a factor of a power of 2, you can never divide 32768Hz by exactly 10.

The achievable "clean" interrupt rates are all powers of 2:

| OCR2A (CTC, prescaler 128) | Timer clock | Rate |
|---|---|---|
| 255 | 256 Hz | **1 Hz** |
| 127 | 256 Hz | **2 Hz** |
| 31 | 256 Hz | **8 Hz** |
| 15 | 256 Hz | **16 Hz** |

---

## Practical options for tenths-of-second display

**Option A — 8 Hz interrupt, approximate tenths:**  
Count 8 ticks/sec, map to tenths via `tenth = tick * 10 / 8`.  
Max display error: ±62 ms. Usually acceptable for a human-readable clock.

**Option B — 16 Hz interrupt, finer approximation:**  
Count 16 ticks per second; `tenth = tick * 10 / 16`.  
Max error: ±31 ms.

**Option C — 128 Hz, software fractional accumulator (exact on average):**  
Use a Bresenham-style accumulator to fire a "tenth" event exactly 10 times per 128 ticks (since 128/10 = 12.8, alternate between 12 and 13 ticks). This gives exact average frequency but slightly irregular individual intervals.

For an RTC display, **Option A (8 Hz)** is almost always sufficient.

User: what about just counting seconds in the interrupt and formatting it into a time and date when actually asked for?

GitHub Copilot: That's actually a cleaner design. The ISR just does one atomic increment, and the heavier date/time calculation only runs when something needs it.

```cpp
volatile uint32_t rtc_epoch = 0;  // seconds since 2000-01-01 00:00:00

ISR(TIMER2_OVF_vect) {
    rtc_epoch++;
}
```

Then a conversion function on demand:

```cpp
typedef struct { uint16_t year; uint8_t month, day, hour, min, sec; } rtc_t;

static const uint16_t days_per_year(uint16_t y) {
    return (y % 4 == 0 && (y % 100 != 0 || y % 400 == 0)) ? 366 : 365;
}

void rtc_get(rtc_t *t) {
    // snapshot atomically
    cli();
    uint32_t e = rtc_epoch;
    sei();

    t->sec  = e % 60; e /= 60;
    t->min  = e % 60; e /= 60;
    t->hour = e % 24; e /= 24;
    // e is now total days since 2000-01-01
    t->year = 2000;
    while (e >= days_per_year(t->year)) { e -= days_per_year(t->year); t->year++; }
    static const uint8_t dom[] = {31,28,31,30,31,30,31,31,30,31,30,31};
    t->month = 1;
    while (true) {
        uint8_t d = (t->month == 2 && days_per_year(t->year) == 366) ? 29 : dom[t->month-1];
        if (e < d) break;
        e -= d; t->month++;
    }
    t->day = e + 1;
}
```

**Advantages over the struct-in-ISR approach:**

| | Struct in ISR | Epoch counter |
|---|---|---|
| ISR work | Multi-branch date logic | One `++` |
| Interrupt jitter risk | Higher | Minimal |
| Setting the clock | Must set each field | Set one `uint32_t` |
| Sleeping (PWR_SAVE) | Same | Same |

**Setting the clock** is also trivial — just compute the epoch value from a known time and assign it. You can also easily serialize it to EEPROM on power-down and restore it on boot.

The only cost is the `rtc_get()` calculation, but since it's only called when you need to display/use the time, that's rarely an issue.

User: how much time (days) will fit in 32-bit worth of seconds?

GitHub Copilot: $$2^{32} \text{ seconds} = 4{,}294{,}967{,}296 \text{ s} \div 86{,}400 = \textbf{49{,}710 \text{ days}} \approx \textbf{136 years}$$

Starting from 2000-01-01 that takes you to around **2136** — more than enough for any practical embedded system.

If you used a signed `int32_t` instead, you'd get half that (~68 years), still fine but no reason to bother.

User: please also make the rtc_set()  function

GitHub Copilot: Read [](file:///c%3A/My/MyProjects/zalt2/Source/MCU/src/rtc.cpp#1-1), lines 1 to 50

Read [](file:///c%3A/My/MyProjects/zalt2/Source/MCU/src/rtc.cpp#50-50), lines 50 to 68

Replacing 2 lines with 23 lines in [](file:///c%3A/My/MyProjects/zalt2/Source/MCU/src/rtc.cpp)


```

```
Added `rtc_set()` at the end of rtc.cpp. It's the exact inverse of `rtc_get()`:

1. Sums full years (accounting for leap years) → days
2. Sums full months in the current year → days
3. Adds the remaining days, hours, minutes, seconds
4. Writes atomically with `cli()`/`sei()`

Usage:
```cpp
rtc_t t = {.sec=0, .min=30, .hour=9, .day=11, .month=4, .year=2026};
rtc_set(&t);
```
