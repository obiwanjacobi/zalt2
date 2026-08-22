; unit_tests.inc - helpers for DeZog unit tests, z88dk z80asm flavour.
; #include this file in every test module.
;
; A test case is a routine whose (public) label starts with "UT_" and that ends
; with TC_END instead of RET.
;
; Checks are written as inline assertion comments (the keyword is spelled out in
; test_lib_mem.asm); DeZog turns them into conditional breakpoints while running
; the tests. Put each one on its own NOP line so a failure points at the right
; source line.
;
; Note: such comments must not be placed inside a MACRO body - z80asm collapses a
; macro expansion onto the invocation line in the .lis file, so DeZog would not
; see the comment.

extern UNITTEST_TEST_READY_SUCCESS

; Ends a test case (replaces the RET).
TC_END: MACRO
    jp UNITTEST_TEST_READY_SUCCESS
    ENDM
