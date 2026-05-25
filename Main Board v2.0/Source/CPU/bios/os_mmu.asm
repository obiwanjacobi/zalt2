; os_mmu.asm - MMU map access routines
; Targets the CPLD MemController via Z80 IO instructions (IN r,(C) / OUT (C),r).
; All ports use C=0xFF; B selects the register via A[15:8].
;
; Vocabulary:
;   map        - the MMU mapping SRAM; holds one page_frame per cell
;   task_id    - 3-bit task identifier; selects which task's entries are active
;                (hi-latch, MAP[10:8], up to 8 tasks)
;   bank       - 4-bit bank index; selects a group of pages within a task
;                (lo-latch, MAP[7:4] effective; full L register written)
;   page_index - 4-bit Z80 page selector; one of 16 x 4KB pages in Z80 space
;                (A[15:12] of IN/OUT, hardwired on PCB to SRAM addr[3:0])
;                passed in A; selects the IO port, not written to latches
;   page_frame  - 16-bit value stored in the map for a (task_id, bank, page_index)
;                cell; drives MA24..MA12 to form the physical address

section code_crt_init

public mmu_map_enable, mmu_map_disable
public mmu_map_read, mmu_map_write
public mmu_bank_read, mmu_bank_write
public mmu_map_bank_read, mmu_map_bank_write
public mmu_prot_write

; =============================================================================
; IO Port Constants
;
; All MMU ports use C = 0xFF (A[7:0]=0xFF).
; B is A[15:8], composed of A[15:12] and A[11:8] as follows.
;
; Latch registers  (A[15:12]="0000", A[11:8]=reg-select, A[7:0]=0xFF)
;   B = 0x00  → 0x00FF  Normal bank    latch (MAP[7:0]  = bank)    (r/w)
;   B = 0x01  → 0x01FF  Normal task_id latch (MAP[10:8] = task_id) (r/w)
;   B = 0x02  → 0x02FF  IO     bank    latch (MAP[7:0]  = bank)    (r/w)
;   B = 0x03  → 0x03FF  IO     task_id latch (MAP[10:8] = task_id) (r/w)
;   B = 0x05  → 0x05FF  Map CE enable  bit0=1:on                   (w/o)
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
; mmu_map_enable
; Enable both MMU mapping RAMs.
; Must be called once before any map read/write.
;
; Destroys: A, BC
; =============================================================================
mmu_map_enable:
    ld   bc, (MMU_B_MAP_CE << 8) | MMU_PORT
    ld   a, 1
    out  (c), a
    ret

; =============================================================================
; mmu_map_disable
; Disable both MMU mapping RAMs.
;
; Destroys: A, BC
; =============================================================================
mmu_map_disable:
    ld   bc, (MMU_B_MAP_CE << 8) | MMU_PORT
    xor a, a        ; a=0
    out  (c), a
    ret

; =============================================================================
; mmu_map_read
; Read a page_frame (16-bit) from the MMU map.
;
; The 11-bit SRAM address is formed from the IO latches + page_index:
;   H[2:0]  → IO task_id latch → SRAM addr[10:8]
;   L       → IO bank    latch → SRAM addr[7:4]  (SRAM addr[3:0] not from CPLD)
;   A[3:0]  → A[15:12] of IN instruction → SRAM addr[3:0] (PCB-hardwired)
;
; Input:   H[2:0] = task_id
;          L      = bank
;          A[3:0] = page_index
; Output:  E      = page_frame low  byte (RAM1[7:0])
;          D      = page_frame high byte (RAM2[4:0], protection bits masked off)
;          H[2:0] = protection bits      (RAM2[7:5] shifted to H[2:0])
; Destroys: A, BC, L
; Assumes:  map is enabled (mmu_map_enable called previously)
; =============================================================================
mmu_map_read:
    ld   c, MMU_PORT             ; C = 0xFF for all MMU accesses

    ; -- Save page_index; A is needed for IO ops, D is free (output) ---------
    ld   d, a                   ; D = page_index temporarily

    ; -- Load IO task_id latch ------------------------------------------------
    ld   b, MMU_B_IO_TASK_ID    ; B=0x03 → port 0x03FF
    ld   a, h
    and  0x07                   ; mask task_id to 3 bits
    out  (c), a

    ; -- Load IO bank latch ---------------------------------------------------
    ld   b, MMU_B_IO_BANK       ; B=0x02 → port 0x02FF
    ld   a, l
    out  (c), a

    ; -- Build B = (page_index << 4) | RAM1 -----------------------------------
    ld   a, d                   ; A = page_index
    and  0x0F
    rlca
    rlca
    rlca
    rlca                        ; page_index in bits [7:4]
    or   MMU_MAP_RAM1
    ld   b, a
    in   e, (c)                 ; E = low byte (RAM1)

    ; -- Build B for RAM2, read -----------------------------------------------
    ld   a, b
    and  0xF0
    or   MMU_MAP_RAM2
    ld   b, a
    in   d, (c)                 ; D = full RAM2 byte (page_frame high + protection)

    ; -- Split RAM2: protection → H[2:0], page_frame → D[4:0] ----------------
    ld   a, d
    and  0xE0                   ; isolate protection bits [7:5]
    rrca
    rrca
    rrca
    rrca
    rrca                        ; shift right 5 → protection bits in [2:0]
    ld   h, a                   ; H = protection bits
    ld   a, d
    and  0x1F                   ; mask page_frame high bits [4:0]
    ld   d, a                   ; D = page_frame high bits only

    ret

; =============================================================================
; mmu_map_write
; Write a page_frame (16-bit) into the MMU map.
; Protection bits in RAM2[7:5] are written as specified in D[7:5].
;
; Input:   H[2:0] = task_id
;          L      = bank
;          A[3:0] = page_index
;          E      = page_frame low  byte (→ RAM1)
;          D[4:0] = page_frame high byte (→ RAM2[4:0])
;          D[7:5] = protected bits
; Destroys: A, BC, HL
; Assumes:  map is enabled (mmu_map_enable called previously)
; =============================================================================
mmu_map_write:
    ld   c, MMU_PORT             ; C = 0xFF for all MMU accesses

    ; -- Pre-compute page_index part of port B, save on stack -----------------
    and  0x0F
    rlca
    rlca
    rlca
    rlca                        ; A = page_index << 4
    push af

    ; -- Load IO task_id latch ------------------------------------------------
    ld   b, MMU_B_IO_TASK_ID    ; B=0x03 → port 0x03FF
    ld   a, h
    and  0x07                   ; mask task_id to 3 bits
    out  (c), a

    ; -- Load IO bank latch ---------------------------------------------------
    ld   b, MMU_B_IO_BANK       ; B=0x02 → port 0x02FF
    ld   a, l
    out  (c), a

    ; -- Write RAM1: low byte (port 0xXEFF) -----------------------------------
    pop  af                     ; A = page_index << 4
    or   MMU_MAP_RAM1
    ld   b, a
    out  (c), e                 ; E → RAM1

    ; -- Write RAM2: page_frame high bits, protection zeroed (port 0xXFFF) ----
    ld   a, b
    and  0xF0
    or   MMU_MAP_RAM2
    ld   b, a
    ld   a, d
    out  (c), a                 ; page_frame high bits → RAM2

    ret

; =============================================================================
; mmu_prot_write
; Write the 3 protection bits (RAM2[7:5]) for a map cell without disturbing
; the page_frame bits (RAM2[4:0]).  Performs a read-modify-write on RAM2.
;
; Input:   H[2:0] = task_id
;          L      = bank
;          A[3:0] = page_index
;          E[2:0] = protection bits to write into RAM2[7:5]
; Destroys: A, BC, DE, HL
; Assumes:  map is enabled (mmu_map_enable called previously)
; =============================================================================
mmu_prot_write:
    ld   c, MMU_PORT             ; C = 0xFF for all MMU accesses

    ; -- Pre-compute page_index part of port B, save on stack -----------------
    and  0x0F
    rlca
    rlca
    rlca
    rlca                        ; A = page_index << 4
    push af

    ; -- Load IO task_id latch ------------------------------------------------
    ld   b, MMU_B_IO_TASK_ID    ; B=0x03 → port 0x03FF
    ld   a, h
    and  0x07
    out  (c), a

    ; -- Load IO bank latch ---------------------------------------------------
    ld   b, MMU_B_IO_BANK       ; B=0x02 → port 0x02FF
    ld   a, l
    out  (c), a

    ; -- Build B for RAM2 port ------------------------------------------------
    pop  af                     ; A = page_index << 4
    or   MMU_MAP_RAM2
    ld   b, a                   ; B = RAM2 port address (stable for in + out)

    ; -- Read current RAM2, clear protection bits ------------------------------
    in   a, (c)
    and  0x1F                   ; keep page_frame bits [4:0], clear prot [7:5]

    ; -- Merge new protection bits into [7:5] ---------------------------------
    ld   d, a                   ; save page_frame bits
    ld   a, e
    and  0x07                   ; mask to 3 bits
    rlca
    rlca
    rlca
    rlca
    rlca                        ; shift left 5 → bits [7:5]
    or   d                      ; merge

    ; -- Write back -----------------------------------------------------------
    out  (c), a

    ret

; =============================================================================
; mmu_bank_read
; Read the current normal-latch values (task_id and bank) that drive the MMU
; during ordinary CPU memory cycles.
;
; Output:  H[2:0] = task_id  (normal task_id latch, MAP[10:8])
;          L      = bank     (normal bank latch,    MAP[7:0])
; Destroys: A, BC
; =============================================================================
mmu_bank_read:
    ld   c, MMU_PORT             ; C = 0xFF for all MMU accesses
    ld   b, MMU_B_TASK_ID       ; B=0x01 → port 0x01FF
    in   h, (c)                 ; H = task_id

    ld   b, MMU_B_BANK          ; B=0x00 → port 0x00FF
    in   l, (c)                 ; L = bank

    ret

; =============================================================================
; mmu_bank_write
; Write the normal-latch values (task_id and bank) that drive the MMU during
; ordinary CPU memory cycles.  Takes effect immediately on the next CPU memory
; cycle; the mapping RAMs will present the new physical address for the new
; task_id:bank context.
;
; Input:   H[2:0] = task_id
;          L      = bank
; Destroys: A, BC
; =============================================================================
mmu_bank_write:
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
; mmu_map_bank_read
; Read the current IO-latch values (task_id and bank) that address the map
; during SRAM programming cycles (mmu_map_read / mmu_map_write).
;
; Output:  H[2:0] = task_id  (IO task_id latch, MAP[10:8])
;          L      = bank     (IO bank    latch, MAP[7:0])
; Destroys: A, BC
; =============================================================================
mmu_map_bank_read:
    ld   c, MMU_PORT             ; C = 0xFF for all MMU accesses
    ld   b, MMU_B_IO_TASK_ID    ; B=0x03 → port 0x03FF
    in   h, (c)                 ; H = task_id

    ld   b, MMU_B_IO_BANK       ; B=0x02 → port 0x02FF
    in   l, (c)                 ; L = bank

    ret

; =============================================================================
; mmu_map_bank_write
; Write the IO-latch values (task_id and bank) that address the map during
; SRAM programming cycles.  Sets the target cell for the next
; mmu_map_read / mmu_map_write call (without performing an access).
;
; Input:   H[2:0] = task_id
;          L      = bank
; Destroys: A, BC
; =============================================================================
mmu_map_bank_write:
    ld   c, MMU_PORT             ; C = 0xFF for all MMU accesses
    ld   b, MMU_B_IO_TASK_ID    ; B=0x03 → port 0x03FF
    ld   a, h
    and  0x07                   ; mask task_id to 3 bits
    out  (c), a

    ld   b, MMU_B_IO_BANK       ; B=0x02 → port 0x02FF
    ld   a, l
    out  (c), a

    ret
