section code_crt_init

; Memory map:
;   ROM 512 kB : 0x1F80000 .. 0x1FFFFFF  MA[24:19] = "111111"
;   RAM 512 kB : 0x1F00000 .. 0x1F7FFFF  MA[24:19] = "111110"
defc ROM_START = 0x1F80000
defc RAM_START = 0x1F00000

public os_init

extern mmu_map_enable
extern mmu_map_write
extern mmu_bank_read
extern mmu_bank_write

; =============================================================================
; os_init
; Initializes the OS startup code.
;
; Destroys: 
; =============================================================================
os_init:
    ; - copy page0 from ROM to RAM (not now)
    ;    assuming we need data in page0 - perhaps not if we always switch task

    ; - set up MMU mapping for os
    call mmu_init
    ret

; Identity-map the first 16 Z80 pages (full 64KB) to task 0, bank 0 in RAM.
; Physical RAM base: 0x1F00000 → page_frame = 0x1F00
; MMU_MP_OS bit is set on all pages.
;   D = 0x1F  (page_frame high byte, constant: MA[24:20] = 11111b, RAM region)
;   E = N     (page_frame low byte for page N: MA[19:12] = N)
; Conveniently, page_index = N = E, so A = E each iteration.
mmu_init:
    ; TODO: we should enable after initialization is done (change CPLD).
    call mmu_map_enable         ; enable mapping SRAMs before any access

    ld   d, $3F                 ; page_frame high byte (RAM region, constant) + OS MP-bit
    xor  a
    ld   e, a                   ; E = 0 (page_frame low byte, starts at page 0)
    ld   b, 16                  ; 16 pages to map (Z80 pages 0..15)

.mmu_init_loop
    push bc                     ; preserve loop counter (mmu_map_write destroys BC)
    ld   h, 0                   ; task_id = 0  (mmu_map_write destroys HL)
    ld   l, 0                   ; bank    = 0
    ld   a, e                   ; page_index = N (= E, since page_frame low = page_index here)
    call mmu_map_write
    pop  bc
    inc  e                      ; advance to next page
    djnz mmu_init_loop
    ret

; TODO: task scheduler and context switching.
os_task_create:
    ret
os_task_destroy:
    ret   
os_task_switch_to:
    ret
