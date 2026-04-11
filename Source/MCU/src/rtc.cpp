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

// seconds since 2000-01-01 00:00:00
volatile uint32_t rtc_epoch = 0;

ISR(TIMER2_OVF_vect) {
    rtc_epoch++;
}

// Days per month (non-leap)
// TODO: PROGMEM?
static const uint8_t dom[] = {31,28,31,30,31,30,31,31,30,31,30,31};

static const uint16_t days_per_year(uint16_t y) {
    return (y % 4 == 0 && (y % 100 != 0 || y % 400 == 0)) ? 366 : 365;
}

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
    uint16_t dpy = days_per_year(t->year);
    while (e >= dpy) {
        e -= dpy; t->year++;
        dpy = days_per_year(t->year);
    }
    
    t->month = 1;
    while (true) {
        uint8_t d = (t->month == 2 && dpy == 366) ? 29 : dom[t->month-1];
        if (e < d) break;
        e -= d;
        t->month++;
    }
    
    t->day = e + 1;
}

void rtc_set(const rtc_t *t) {
    uint32_t e = 0;

    // accumulate full years since 2000
    for (uint16_t y = 2000; y < t->year; y++) {
        e += days_per_year(y) * 24 * 60 * 60;
    }
    
    // accumulate full months in current year
    for (uint8_t m = 1; m < t->month; m++) {
        e += ((m == 2 && is_leap(t->year)) ? 29 : dom[m-1]) * 24 * 60 * 60;
    }

    e += (t->day - 1) * 24 * 60 * 60;          // days in current month (0-based)
    e  = e + t->hour * 60 * 60;
    e  = e + t->min * 60;
    e  = e + t->sec;

    cli();
    rtc_epoch = e;
    sei();
}
