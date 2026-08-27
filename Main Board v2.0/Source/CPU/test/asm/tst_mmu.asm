; tst_mmu.asm - unit test stubs for MMU functions

public var_tst_mmu_bank
defw var_tst_mmu_bank

public mmu_bank_read
; Output:  H[2:0] = task_id  (normal task_id latch, MAP[10:8])
;          L      = bank     (normal bank latch,    MAP[7:0])
; Destroys: A, BC
; =============================================================================
mmu_bank_read:
    ld hl, var_tst_mmu_bank
    ld c, (hl)
    inc hl
    ld b, (hl)

    ld h, b
    ld l, c
    ret


public mmu_bank_write
; Input:   H[2:0] = task_id
;          L      = bank
; Destroys: A, BC
; =============================================================================
mmu_bank_write:
    ld b, h
    ld c, l
    
    ld hl, var_tst_mmu_bank
    ld (hl), c
    inc hl
    ld (hl), b

    ld h, b
    ld l, c
    ret
