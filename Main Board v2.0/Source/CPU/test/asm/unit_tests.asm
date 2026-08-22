; unit_tests.asm - DeZog unit test runtime (z88dk z80asm flavour).
;
; DeZog locates these labels by name in the map file, so they must stay
; public and keep their exact spelling:
;   UNITTEST_TEST_WRAPPER    - entry point, called once per test case
;   UNITTEST_CALL_ADDR       - the CALL that DeZog patches with the test address
;   UNITTEST_TEST_READY_SUCCESS - breakpoint marking a passed test case
;   UNITTEST_STACK           - stack used while a test case runs
;   UNITTEST_START           - initialization, run before every test case
;
; This module must be linked first so that it sits at the load address.

public UNITTEST_TEST_WRAPPER, UNITTEST_CALL_ADDR, UNITTEST_TEST_READY_SUCCESS
public UNITTEST_STACK_BOTTOM, UNITTEST_STACK, UNITTEST_START

UNITTEST_TEST_WRAPPER:
    di
    ld sp, UNITTEST_STACK
UNITTEST_CALL_ADDR:
    call 0x0000             ; target is patched by DeZog per test case
    nop

UNITTEST_TEST_READY_SUCCESS:
    jr UNITTEST_TEST_READY_SUCCESS   ; DeZog breaks here on success

; Stack for the test cases (50 words).
UNITTEST_STACK_BOTTOM:
    defw 0
    defs 2*50
UNITTEST_STACK:
    defw 0

; Initialization, executed before each test case. SP is set up by the wrapper.
UNITTEST_START:
    di
    ret
