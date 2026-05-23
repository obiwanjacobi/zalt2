; memory_controller.asm - MMU map access routines
; Targets the CPLD MemController via Z80 IO instructions (IN r,(C) / OUT (C),r).
; All ports use C=0xFF; B selects the register via A[15:8].
;
; Vocabulary:
;   map        - the MMU mapping SRAM; holds one page_frame per cell
;   task_id    - 3-bit task identifier; selects which task's entries are active
;                (hi-latch, MAP[10:8], up to 8 tasks)
;   bank       - 4-bit bank index; selects a group of pages within a task
;                (lo-latch upper nibble, MAP[7:4], up to 16 banks per task)
;   page_index - 4-bit Z80 page selector; one of 16 x 4KB pages in Z80 space
;                (A[15:12], hardwired on PCB to SRAM addr[3:0])
;   page_frame  - 16-bit value stored in the map for a (task_id, bank, page_index)
;                cell; drives MA24..MA12 to form the physical address

section code_crt_init

public _mmu_map_enable, _mmu_map_disable
public _mmu_map_read, _mmu_map_write
public _mmu_bank_read, _mmu_bank_write
public _mmu_map_bank_read, _mmu_map_bank_write
public _mmu_prot_write

; =============================================================================
; IO Port Constants
;
; All MMU ports use C = 0xFF (A[7:0]=0xFF).
; B is A[15:8], composed of A[15:12] and A[11:8] as follows.
;
; Latch registers  (A[15:12]="0000", A[11:8]=reg-select, A[7:0]=0xFF)
;   B = 0x00  → 0x00FF  Normal bank    latch (MAP[7:0]  = bank:page_index) (r/w)
;   B = 0x01  → 0x01FF  Normal task_id latch (MAP[10:8] = task_id)         (r/w)
;   B = 0x02  → 0x02FF  IO     bank    latch (MAP[7:0]  = bank:page_index) (r/w)
;   B = 0x03  → 0x03FF  IO     task_id latch (MAP[10:8] = task_id)         (r/w)
;   B = 0x05  → 0x05FF  Map CE enable  bit0=1:on                           (w/o)
;
; Map data ports  (A[11:8]=0xE/0xF, A[15:12]=page_index, A[7:0]=0xFF)
;   B = (page_index << 4) | 0x0E  → RAM1 low  byte of page_frame
;   B = (page_index << 4) | 0x0F  → RAM2 high byte of page_frame
; =============================================================================

defc MMU_PORT           = 0xFF  ; C register for all MMU IO (A[7:0])

; Latch-register B values
defc MMU_B_BANK         = 0x00  ; 0x00FF  normal bank    latch  MAP[7:0]
defc MMU_B_TASK_ID      = 0x01  ; 0x01FF  normal task_id latch  MAP[10:8]
defc MMU_B_IO_BANK      = 0x02  ; 0x02FF  IO bank        latch  MAP[7:0]
defc MMU_B_IO_TASK_ID   = 0x03  ; 0x03FF  IO task_id     latch  MAP[10:8]
defc MMU_B_MAP_CE       = 0x05  ; 0x05FF  map CE enable  (write-only)

; Map data port low-nibble of B (high nibble = page_index)
defc MMU_MAP_RAM1       = 0x0E  ; A[11:8]=0xE → RAM1 (low  byte of page_frame)
defc MMU_MAP_RAM2       = 0x0F  ; A[11:8]=0xF → RAM2 (high byte of page_frame)

; Protection bit values (RAM2[7:5]) - read is implicitly allowed
defc MMU_MMP_OS         = 0x01  ; Operating System
defc MMU_MMP_WRITE      = 0x02  ; Write
defc MMU_MMP_EXECUTE    = 0x04  ; Execute

; =============================================================================
; _mmu_map_enable
; Enable both MMU mapping RAMs.
; Must be called once before any map read/write.
;
; Destroys: A, BC
; =============================================================================
_mmu_map_enable:
    ld   bc, (MMU_B_MAP_CE << 8) | MMU_PORT
    ld   a, 1
    out  (c), a
    ret

; =============================================================================
; _mmu_map_disable
; Disable both MMU mapping RAMs.
;
; Destroys: A, BC
; =============================================================================
_mmu_map_disable:
    ld   bc, (MMU_B_MAP_CE << 8) | MMU_PORT
    xor a, a        ; a=0
    out  (c), a
    ret

; =============================================================================
; _mmu_map_read
; Read a page_frame (16-bit) from the MMU map.
;
; The 11-bit map cell address is task_id : bank : page_index
;   H[2:0]  → IO task_id latch → MAP[10:8]  (map addr bits [10:8])
;   L[7:4]  → IO bank    latch → MAP[7:4]   (map addr bits [7:4])
;   L[3:0]  → A[15:12] of IN  → map addr[3:0] (PCB-hardwired, = page_index)
;   (L[3:0] is also written to io_bank[3:0] but those CPLD pins are NC)
;
; Input:   H[2:0] = task_id
;          L[7:4] = bank
;          L[3:0] = page_index
; Output:  HL = page_frame (protection bits masked off)
;          L = low  byte        (RAM1[7:0])
;          H = page_frame high  (RAM2[4:0])
;          E  = protection bits    (RAM2[7:5] shifted to E[2:0])
; Destroys: A, BC
; Assumes:  map is enabled (_mmu_map_enable called previously)
; =============================================================================
_mmu_map_read:
    ld   c, MMU_PORT             ; C = 0xFF for all MMU accesses

    ; -- Load IO task_id latch with task_id (H[2:0]) --------------------------
    ld   b, MMU_B_IO_TASK_ID    ; B=0x03 → port 0x03FF
    ld   a, h
    and  0x07                   ; mask to 3 bits
    out  (c), a

    ; -- Load IO bank latch with bank:page_index (L) --------------------------
    ld   b, MMU_B_IO_BANK       ; B=0x02 → port 0x02FF
    ld   a, l
    out  (c), a

    ; -- Build B[7:4] = page_index = L[3:0] -----------------------------------
    ld   a, l
    and  0x0F                   ; A = page_index
    rlca
    rlca
    rlca
    rlca                        ; A = page_index in bits [7:4], zeros in [3:0]

    ; -- Read RAM1: low byte of page_frame (port 0xXEFF) -----------------------
    or   MMU_MAP_RAM1           ; A[3:0] = 0xE
    ld   b, a
    in   l, (c)                 ; L = low byte  (HL input consumed, now output)

    ; -- Read RAM2: page_frame high bits + protection bits (port 0xXFFF) -------
    ld   a, b
    and  0xF0                   ; keep page_index in bits [7:4]
    or   MMU_MAP_RAM2           ; A[3:0] = 0xF
    ld   b, a
    in   h, (c)                 ; H = full RAM2 byte

    ; -- Split RAM2: protection bits → E[2:0], page_frame bits → H[4:0] ------
    ld   a, h
    and  0xE0                   ; isolate protection bits [7:5]
    rrca
    rrca
    rrca
    rrca
    rrca                        ; shift right 5 → protection bits in [2:0]
    ld   e, a                   ; E = protection bits
    ld   a, h
    and  0x1F                   ; mask page_frame high bits [4:0]
    ld   h, a                   ; H = page_frame high bits only

    ret

; =============================================================================
; _mmu_map_write
; Write a page_frame (16-bit) into the MMU map.
;
; The 11-bit map cell address is task_id : bank : page_index (same as read).
;
; Input:   H[2:0] = task_id
;          L[7:4] = bank
;          L[3:0] = page_index
;          E      = low  byte of page_frame        (→ RAM1)
;          D[4:0] = high byte of page_frame        (→ RAM2[4:0]; D[7:5] ignored, protection bits zeroed)
; Destroys: A, BC
; Assumes:  map is enabled (_mmu_map_enable called previously)
; =============================================================================
_mmu_map_write:
    ld   c, MMU_PORT             ; C = 0xFF for all MMU accesses

    ; -- Load IO task_id latch with task_id (H[2:0]) --------------------------
    ld   b, MMU_B_IO_TASK_ID    ; B=0x03 → port 0x03FF
    ld   a, h
    and  0x07                   ; mask to 3 bits
    out  (c), a

    ; -- Load IO bank latch with bank:page_index (L) --------------------------
    ld   b, MMU_B_IO_BANK       ; B=0x02 → port 0x02FF
    ld   a, l
    out  (c), a

    ; -- Build B[7:4] = page_index = L[3:0] -----------------------------------
    ld   a, l
    and  0x0F                   ; A = page_index
    rlca
    rlca
    rlca
    rlca                        ; A = page_index in bits [7:4], zeros in [3:0]

    ; -- Write RAM1: low byte of page_frame (port 0xXEFF) ---------------------
    or   MMU_MAP_RAM1           ; A[3:0] = 0xE
    ld   b, a
    out  (c), e                 ; E (low byte) → RAM1

    ; -- Write RAM2: page_frame bits only, protection bits zeroed (port 0xXFFF)
    ld   a, b
    and  0xF0                   ; keep page_index in bits [7:4]
    or   MMU_MAP_RAM2           ; A[3:0] = 0xF
    ld   b, a
    ld   a, d
    and  0x1F                   ; mask off protection bits [7:5]
    out  (c), a                 ; write page_frame high bits → RAM2

    ret

; =============================================================================
; _mmu_prot_write
; Write the 3 protection bits (RAM2[7:5]) for a map cell without disturbing
; the page_frame bits (RAM2[4:0]).  Performs a read-modify-write on RAM2.
;
; Input:   H[2:0] = task_id
;          L[7:4] = bank
;          L[3:0] = page_index
;          E[2:0] = protection bits to write into RAM2[7:5]
; Destroys: A, BC, DE, HL
; Assumes:  map is enabled (_mmu_map_enable called previously)
; =============================================================================
_mmu_prot_write:
    ld   c, MMU_PORT             ; C = 0xFF for all MMU accesses

    ; -- Load IO latches (same address setup as _mmu_map_read/write) ----------
    ld   b, MMU_B_IO_TASK_ID    ; B=0x03 → port 0x03FF
    ld   a, h
    and  0x07                   ; mask task_id to 3 bits
    out  (c), a

    ld   b, MMU_B_IO_BANK       ; B=0x02 → port 0x02FF
    ld   a, l
    out  (c), a

    ; -- Build B for RAM2 port: B = (page_index << 4) | 0x0F -----------------
    ld   a, l
    and  0x0F                   ; A = page_index
    rlca
    rlca
    rlca
    rlca                        ; page_index in bits [7:4]
    or   MMU_MAP_RAM2           ; A[3:0] = 0xF
    ld   b, a                   ; B = RAM2 port address (stable for in + out)

    ; -- Read current RAM2 ----------------------------------------------------
    in   a, (c)                 ; A = current RAM2 (page_frame[4:0] | prot[7:5])
    and  0x1F                   ; clear current protection bits, keep page_frame

    ; -- Merge new protection bits into [7:5] ---------------------------------
    ld   d, a                   ; save page_frame bits
    ld   a, e
    and  0x07                   ; mask to 3 protection bits
    rlca
    rlca
    rlca
    rlca
    rlca                        ; shift left 5 → bits [7:5]
    or   d                      ; merge with page_frame bits

    ; -- Write modified RAM2 --------------------------------------------------
    out  (c), a                 ; write back RAM2 with new protection bits

    ret

; =============================================================================
; _mmu_bank_read
; Read the current normal-latch values (task_id and bank) that drive the MMU
; during ordinary CPU memory cycles.
;
; Output:  H[2:0] = task_id  (normal task_id latch, MAP[10:8])
;          L      = bank     (normal bank latch,    MAP[7:0])
; Destroys: A, BC
; =============================================================================
_mmu_bank_read:
    ld   c, MMU_PORT             ; C = 0xFF for all MMU accesses
    ld   b, MMU_B_TASK_ID       ; B=0x01 → port 0x01FF
    in   h, (c)                 ; H = task_id

    ld   b, MMU_B_BANK          ; B=0x00 → port 0x00FF
    in   l, (c)                 ; L = bank

    ret

; =============================================================================
; _mmu_bank_write
; Write the normal-latch values (task_id and bank) that drive the MMU during
; ordinary CPU memory cycles.  Takes effect immediately on the next CPU memory
; cycle; the mapping RAMs will present the new physical address for the new
; task_id:bank context.
;
; Input:   H[2:0] = task_id
;          L      = bank
; Destroys: A, BC
; =============================================================================
_mmu_bank_write:
    ld   c, MMU_PORT             ; C = 0xFF for all MMU accesses
    ld   b, MMU_B_TASK_ID       ; B=0x01 → port 0x01FF
    ld   a, h
    and  0x07                   ; mask task_id to 3 bits
    out  (c), a

    ld   b, MMU_B_BANK          ; B=0x00 → port 0x00FF
    ld   a, l
    out  (c), a

    ret

; =============================================================================
; _mmu_map_bank_read
; Read the current IO-latch values (task_id and bank) that address the map
; during SRAM programming cycles (_mmu_map_read / _mmu_map_write).
;
; Output:  H[2:0] = task_id  (IO task_id latch, MAP[10:8])
;          L      = bank     (IO bank    latch, MAP[7:0])
; Destroys: A, BC
; =============================================================================
_mmu_map_bank_read:
    ld   c, MMU_PORT             ; C = 0xFF for all MMU accesses
    ld   b, MMU_B_IO_TASK_ID    ; B=0x03 → port 0x03FF
    in   h, (c)                 ; H = task_id

    ld   b, MMU_B_IO_BANK       ; B=0x02 → port 0x02FF
    in   l, (c)                 ; L = bank

    ret

; =============================================================================
; _mmu_map_bank_write
; Write the IO-latch values (task_id and bank) that address the map during
; SRAM programming cycles.  Sets the target cell for the next
; _mmu_map_read / _mmu_map_write call (without performing an access).
;
; Input:   H[2:0] = task_id
;          L      = bank
; Destroys: A, BC
; =============================================================================
_mmu_map_bank_write:
    ld   c, MMU_PORT             ; C = 0xFF for all MMU accesses
    ld   b, MMU_B_IO_TASK_ID    ; B=0x03 → port 0x03FF
    ld   a, h
    and  0x07                   ; mask task_id to 3 bits
    out  (c), a

    ld   b, MMU_B_IO_BANK       ; B=0x02 → port 0x02FF
    ld   a, l
    out  (c), a

    ret
