User: I am investigating what mass-storage to attach to my 20HMz z80 homebrew computer.
The main board that is currently being made works on a (custom) bus. The idea is to have smart-devices on the bus that each perform a task, like mass-storage, video display, network etc.
The protocol to communicate with a smart-device (SD) is not final, but the current idea is to have the SD do DMA to exchange large amounts of data.
The protocol is also on a higher abstraction level than sectors or blocks (for mass storage). The file system (FAT16/32) will be imlemented in the SD.
My initial idea was to try to interface with an old IDE HDD, but perhaps there are easier options to persue. Any thoughts?

GitHub Copilot: I’m checking the existing project notes around storage and the smart-device bus so the recommendation is grounded in your current architecture rather than generic advice.

Read [](file:///c%3A/My/MyProjects/zalt2/Main%20Board%20v2.0/readme.md)

Read [](file:///c%3A/My/MyProjects/zalt2/readme.md)

Read [](file:///c%3A/My/MyProjects/zalt2/chats/SPI%20SD%20Card.md)

For your architecture, an old IDE HDD is probably the wrong first target. Since the smart-device owns the filesystem and the Z80 only sees higher-level file operations, the best storage medium is the one that is easiest for the smart-device to drive reliably, not the one that is most “native” to the Z80 era.

My recommendation is: start with an SD card, likely over SPI for rev 1. If you later want more throughput, move to a controller that can do 4-bit SD mode or use a faster MCU. SD gives you cheap media, low power, no 12 V rail, simple mechanics, easy replacement, and straightforward MCU support. For the abstraction you described, it is a very good fit.

Old IDE HDDs are attractive emotionally, but they cost you a lot:
- awkward power requirements
- bulk and noise
- aging, failure-prone media
- more annoying electrical/timing behavior than modern removable flash
- little benefit if your smart-device hides sectors and ATA details anyway

If you want something “IDE-like” without the pain of spinning disks, CompactFlash is the interesting middle ground. CF in True IDE mode is much friendlier than a real HDD, still has the retro flavor, and is electrically simpler to integrate than a legacy drive. If your goal is experimentation with a parallel storage interface, CF is a better path than an actual HDD.

I’d rank the options like this:

1. SD card over SPI
Best first implementation. Lowest risk, fastest path to a working mass-storage device.

2. CompactFlash in True IDE mode
Good if you specifically want a parallel, retro-style storage module and removable media.

3. eMMC
Technically good for a compact fixed “system disk,” but usually worse for hobbyist bring-up because of package and routing pain.

4. Old IDE HDD
Only worth it as a later novelty or engineering challenge.

5. USB flash drive
Avoid for now. USB host support adds complexity for very little payoff in your design.

For the protocol, I’d keep a strict split between control plane and data plane:
- control: open, create, close, read, write, seek, stat, enumerate
- data: DMA transfers of file payload only

That keeps the Z80 side clean. The smart-device should own:
- FAT16/32 parsing
- directory traversal
- filename handling
- current file position
- buffering and prefetch
- write-back caching

On the Z80 side, expose opaque handles rather than paths after open. Something like:
- `open(path, mode) -> handle`
- `read(handle, addr, len) -> actual_len`
- `write(handle, addr, len) -> actual_len`
- `seek(handle, pos)`
- `close(handle)`
- `find_first/find_next`
- `mkdir`, `delete`, `rename` later if needed

A few design choices will make this much smoother:
- Use DMA in 256 B or 512 B chunks, not tiny transfers.
- Let the device prefetch sequential reads.
- Keep writes buffered and commit on `close` or `flush`.
- Return simple status/error codes; don’t mirror FAT internals to the Z80.
- Support sequential access first. Random seek can come later.
- Consider 8.3 filenames first, then add long filenames only if you really need them.

If you want a practical first target, I’d build a storage smart-device around:
- an SD card
- an MCU with solid SPI and enough RAM for a few sector buffers
- a handle-based file API
- DMA bursts into Z80 RAM

That gets you to a usable filesystem quickly. If later you still want the retro satisfaction of “IDE,” make a second mass-storage card based on CF rather than a spinning HDD.

Natural next steps:
1. I can help sketch a minimal command set for the Z80-to-storage-device protocol.
2. I can help compare MCU choices for the storage smart-device.
3. I can help define a DMA-friendly file API that fits your bus cleanly.

User: Is there a CF size I should be aware of? Like the new modern ones with many GBs - do they introduce extra complexity?

GitHub Copilot: Yes. The main capacity-related complexity is not the CF interface itself, but the addressing mode and filesystem choices that come with larger cards.

For CF in True IDE mode, the practical breakpoints are:

1. Up to 2 GB: easiest if you want FAT16.
2. Above 2 GB up to 128 GiB: still straightforward if you use FAT32 and 28-bit LBA.
3. Above 128 GiB: you need 48-bit LBA support, which adds command and register-handling complexity.

So if your storage device implements FAT16/32 and talks ATA/IDE-style commands to the CF card, “modern big” CF cards do not automatically become hard, but once you cross 128 GiB you are in a different class of protocol support. For a first implementation, I would avoid that entirely.

There is also a filesystem breakpoint:
- Small cards let you stay on FAT16 if you want the simplest code.
- Larger cards push you toward FAT32.
- Very large cards may come preformatted as exFAT, but that is not a hardware problem; you can usually reformat them to FAT32 if the size is reasonable for your use.

For your project, I would deliberately choose something modest, like 512 MB to 8 GB, or at most 16 GB or 32 GB. That gives you plenty of space, keeps you away from 48-bit LBA, and avoids any temptation to support exFAT. If you want the absolute simplest path, 1 GB to 2 GB is a very comfortable range.

The bigger practical issue with CF today is often not size but card quality and compatibility. New random CF cards can be inconsistent. Industrial CF cards or older genuine-brand cards tend to behave more predictably in True IDE mode.

Short version: large CF cards do add some complexity, but mostly only at the filesystem and LBA48 boundary. If you stay at 32 GB or below, and ideally much smaller, you avoid most of it.

User: can you address a CF > 2GB as one < 2GB (FAT16) - just wasting the rest?

GitHub Copilot: Yes, in principle. A CF card larger than 2 GB can usually be used as if it were a smaller FAT16 volume by creating a small partition at the front and ignoring the rest.

A few distinctions matter:

- Hardware addressing: the CF card still reports its real full capacity. Your smart-device can choose to use only the first N sectors.
- Filesystem: you format only that first region as FAT16.
- Unused space: the remainder just stays unpartitioned or unused.

So from your firmware’s point of view, you can absolutely say: “I only expose the first 1 GB or 2 GB of this card” and treat it like a small disk.

The simplest ways to do it are:

1. Create a partition smaller than 2 GB at LBA 0 and format that FAT16.
2. Ignore partitioning entirely and build a FAT16 volume directly on the first part of the medium, if your firmware is happy treating the device as “superfloppy” style media.

The catch is compatibility, not theory:

- Some PC formatting tools may prefer FAT32 on larger cards.
- Some OSes may not like odd partitioning choices on large removable media.
- If the card comes preformatted, you’ll likely want to repartition/reformat it yourself.
- If your firmware reads MBR partitions, it must honor the partition size and not the raw device size.
- If your firmware skips MBR and mounts a raw FAT volume, then you just ignore everything after the FAT16 region.

For your project, this is a valid simplification strategy. In fact, it is a good one if you want:
- FAT16 only
- fixed small-volume assumptions
- simpler testing and recovery

I would still prefer getting an actually small CF card if convenient, because it reduces ambiguity during bring-up. But if larger cards are easier to source, using only the first 512 MB to 2 GB is perfectly reasonable.

One practical warning: FAT16 “2 GB” is not a universal hard line in the real world. The exact usable limit depends on sector size and cluster-count rules. If you want the least friction, target something comfortably below the edge, like 1 GB or 1.9 GB, rather than trying to hit the absolute maximum exactly.

If you want, I can outline the simplest on-device strategy for this:
1. raw FAT16 volume with no partition table
2. MBR with one small FAT16 partition
3. smart-device firmware that clamps visible capacity regardless of actual CF size

User: got it.
what MCU would be suitable?
My idea for DMA is to use a complete 4k memory page that contains both control commands (ring) buffer as well as the data (ring) buffer.
Would be ideal if the MCU had some sort of external memory interface. 

GitHub Copilot: For what you described, the first thing to pin down is this: do you want the MCU to be a bus master that actively drives the Z80 memory bus during DMA, or do you want a permanently shared 4 kB page that both sides can access through some arbitration logic?

Those lead to different MCU requirements.

If you want true DMA into Z80 RAM, an “external memory interface” on the MCU is helpful, but not in the way people usually mean. Most MCU external bus interfaces are for the MCU to access external SRAM, NOR flash, LCDs, or FPGA registers as a master. They do not automatically make the MCU a nice bus-slave on someone else’s system bus. So if your DMA plan is “MCU grabs the bus and writes into a 4 kB page of system RAM,” then what matters is:
- fast GPIO or a parallel bus peripheral
- predictable timing
- enough DMA capability internally to move data from SDIO/SPI into staging RAM
- enough RAM for buffering
- acceptable glue logic complexity

If instead you create a dedicated 4 kB dual-ported or arbitrated shared page, then the MCU can talk to that page as external memory and the Z80 can map it through the MMU. That is much cleaner architecturally. In that model, the MCU is not pretending to be a RAM chip on the Z80 bus; both sides just exchange descriptors and payloads through shared memory.

For MCU families, I would shortlist these:

1. STM32F4/F7 with FSMC/FMC
Best overall fit. These parts have a well-known async external memory controller, decent DMA, lots of RAM options, SDIO/SDMMC on many variants, and a big hobby ecosystem. An STM32F407 or STM32F767 is a strong candidate.

2. ATSAM / SAME70 / SAMV71 with EBI/SMC
Very capable for external bus work and storage tasks. Good if you want a more industrial feel and strong peripheral set. Slightly less hobby-friendly than STM32, but technically solid.

3. NXP LPC177x/178x or similar parts with EMC
Usable, though I would usually pick STM32 first unless you already know the NXP toolchain well.

4. Teensy-class i.MX RT boards
Very fast, but often less convenient for clean external parallel bus interfacing than an STM32 with FMC. Great compute, less obviously the simplest fit for this exact job.

The part I would not choose for this specific card is an AVR-class MCU like the ATmega1284P if you want serious DMA-style mass storage. It can do the logic, but once you add FAT, buffering, ring management, and high-speed bus transfers, you will start fighting RAM size, throughput, and software complexity.

My concrete recommendation would be:
- STM32F407 if you want a pragmatic first implementation
- STM32F767 or H7-class only if you know you need more headroom
- use SD card first, not CF first, unless retro-parallel storage is the actual goal

About your 4 kB page idea: that is a good idea. In fact, it is better than trying to expose lots of registers. I would structure it as:
- a command ring
- a completion ring
- one or two large data regions
- ownership flags / producer-consumer indices
- a very small doorbell/interrupt mechanism outside the page

That gives you a transport layer that can serve storage, network, and video devices with the same model.

A few practical observations:
- 4 kB is large enough to be useful and small enough to reason about.
- Make the rings descriptor-based, not byte-stream-only.
- Keep command descriptors fixed-size.
- Put actual file data in one or two larger contiguous buffers.
- Use separate producer/consumer pointers for Z80 and MCU.
- Avoid per-byte handshakes entirely.

One important caveat: if the shared page lives in the normal Z80 RAM space and the MCU writes it during DMA, cache coherency is not an issue for a Z80, but page ownership is. You need a very crisp rule about when the Z80 may touch a buffer and when the MCU may touch it. A double-buffered region is usually easier than a fully general byte-ring for payload data.

If you want the simplest hardware architecture, I would do this:
1. MCU with FMC/FSMC and SDIO/SDMMC, preferably STM32F4/F7.
2. Shared 4 kB page implemented as external SRAM or FPGA/CPLD-backed memory window.
3. Descriptor rings in the first part of the page, data buffers in the rest.
4. MCU reads SD card into its own RAM first, then copies or DMA-pushes into the shared page.
5. Z80 consumes from the shared page without touching storage protocol details.

If you want the simplest firmware architecture, I would not try to make the MCU directly emulate a memory device on the Z80 bus. I would use the shared-page design instead.

If you want, I can do one of these next:
1. sketch a concrete 4 kB page layout with ring headers and descriptors
2. compare a few specific STM32 parts for this role
3. outline the bus-arbitration options for “true DMA into Z80 RAM” versus “shared-page transport”

User: Each smart device (SD) has it's own dma capability (instead of a central DMA controller on the motherboard like with a PC). The SD can request the (CPU) bus and access the memory without contention. Clearly this time should be as short as possible. 

GitHub Copilot: In that model, I would treat the smart device as two blocks, not one:

- an MCU that handles the slow, stateful work: filesystem, SD/CF protocol, buffering, command parsing
- a small CPLD/FPGA or dedicated bus-state machine that handles the fast, timing-critical bus master cycle generation

That split fits your bus-master-per-device architecture much better than trying to make the MCU do everything directly.

A plain MCU external memory interface is usually not the deciding feature here. It helps the MCU talk to parallel memory, but bus-mastering a Z80 system cleanly means you also need:
- bus request/grant handling
- address/data/control signal sequencing
- wait-state handling if needed
- clean tri-state behavior
- short, deterministic burst transfers

Those are exactly the parts a CPLD/FPGA is good at. The MCU is good at everything else.

So the ideal smart-device architecture is:

1. MCU fills a local buffer from storage or prepares data to write.
2. When enough data is ready, the device requests the Z80 bus.
3. A CPLD/FPGA takes over the bus and performs a short burst into RAM.
4. Bus is released immediately.
5. MCU continues background work while the CPU runs again.

That keeps bus-hold time short, which is the right optimization target.

For MCU choice under that architecture, I would prioritize:
- enough SRAM for prefetch/write-back buffers
- good SDIO/SDMMC or at least fast SPI
- decent internal DMA
- enough performance to handle FAT and command queues comfortably
- easy toolchain and board availability

I would look at these classes:

1. STM32F4
Very good baseline. Enough RAM/performance for filesystem work, strong peripheral set, easy to source used boards/modules.

2. STM32F7 or H7
Good if you want more buffering, more throughput, or multiple services later. Probably more than you need for a first storage device.

3. SAME70 / SAMV71
Technically strong, especially for a more serious bus-oriented design, but I’d still usually pick STM32 first unless you already prefer Microchip’s ARM parts.

For a first device, an STM32F407-class MCU plus a small CPLD is a very sensible combination.

What I would not optimize for first is “MCU with external memory bus.” If the CPLD is generating the actual Z80 bus cycles, the MCU no longer needs to directly present itself as a bus master on the motherboard. It only needs a fast local link to the CPLD and enough RAM to stage bursts.

The key architectural rule should be: never hold the CPU bus while talking to the storage medium.

That means:
- read from SD/CF into local RAM first
- then request the bus and blast a burst into system RAM
- for writes, pull a burst from RAM quickly, release the bus, then write to media afterward

So your DMA becomes “burst memory exchange,” not “live storage transaction.” That is the right design.

If you want to minimize bus occupancy further, your 4 kB page idea is strong, but I would use it as a mailbox plus staging window, not as a constantly shared live structure. For example:
- one small command ring
- one completion ring
- one or two data buffers
- ownership bits per buffer

Then the MCU can prefetch a 512-byte sector or file chunk locally, request the bus once, copy it into the 4 kB page, release the bus, and let the Z80 consume it later without another bus arbitration event.

So the practical recommendation becomes:

- MCU: STM32F407 or similar
- Bus interface: small CPLD/FPGA
- Media: SD first, CF second if you want the retro interface
- DMA strategy: prebuffer locally, burst over the bus, release immediately

If you want, I can next sketch:
1. a concrete smart-device hardware partition between MCU and CPLD
2. a bus-master DMA burst protocol for your 4 kB page
3. a rough timing budget for how long a 256 B, 512 B, or 4 kB transfer would hold the Z80 bus at 20 MHz

User: Splitting into a CPLD-DMA, a (transfer) RAM and a MCU will make the hardware more complicated. You need to mux the RAM between the CPLD and the MCU. Also using a ring buffer in the 4k shared page - it is not as straight-forward to implement in a CPLD? it is not a mere 'increment address' until you're done - scenario.

GitHub Copilot: Yes. That is the real cost of the “MCU + CPLD + transfer RAM” split: the timing gets cleaner, but the local card architecture gets more complicated.

And you are also right about the ring buffer point: a general-purpose ring is not something I would want the CPLD to “own” in the sense of parsing variable-length commands, tracking wraparound, dealing with partial records, and arbitrating with the MCU. That pushes too much control logic into the programmable logic.

The cleaner way to think about it is this: the ring lives at the protocol level, but the CPLD should only execute very small, fixed transfer primitives. The MCU owns the ring semantics.

So instead of:

- CPLD understands the shared 4 kB page structure
- CPLD walks command/data rings
- CPLD decides where the next payload begins

I would do:

- MCU parses the command ring in shared memory
- MCU decides: source address, destination address, length, direction
- MCU then arms the CPLD with a very small descriptor like “copy 512 bytes between local buffer X and system address Y”
- CPLD performs only the burst
- MCU updates the shared-page ring metadata afterward

That keeps the CPLD to “increment address until done,” which is exactly the level it should operate at. The ring buffer remains a software structure, not a hardware state machine.

So your objection is valid, but it argues for narrowing the CPLD’s role, not necessarily removing it.

If you want to reduce hardware even further, there are really three viable architectures:

1. MCU only, no local transfer RAM, no CPLD
Possible, but only if you are willing to accept relatively slow and timing-sensitive DMA bus service. At 20 MHz Z80, I would not choose this unless the DMA bursts are tiny and infrequent.

2. MCU + CPLD, but no shared local RAM between them
This is often the sweet spot. The MCU keeps its own SRAM buffers internally. The CPLD is just a bus master engine. The link between MCU and CPLD is a few control/status registers plus maybe an 8- or 16-bit local data path/FIFO. No external transfer RAM to mux.

3. MCU + dual-port RAM, optionally no CPLD or minimal CPLD
Architecturally elegant, but dual-port RAM parts are less common and may be overkill unless you really want a true shared-memory card model.

Given your concern, I would avoid “CPLD + external transfer RAM + MCU” unless you have a very clear reason for it. It adds a lot of board complexity for something the MCU’s internal RAM can often handle perfectly well.

A better compromise is:

- MCU stores prefetched file data in its own RAM
- MCU manages the 4 kB shared-page protocol logically
- CPLD only performs bus-request, bus-master burst, bus-release
- CPLD gets a simple transfer descriptor from the MCU
- no CPLD awareness of ring wrap, handles, file state, or variable-length protocol records

That also fixes your ring-buffer concern. The shared 4 kB page can still use rings, but only the MCU and Z80 software need to understand them. The DMA hardware only copies byte ranges.

If you want to simplify even more, I would question whether you need a true ring for the data area at all. For a storage device, a ping-pong or mailbox scheme is often much easier:

- command area
- response area
- buffer A
- buffer B

Ownership bits:
- Z80 owns A, MCU fills B
- then swap

That is much easier in both firmware and hardware than a general ring, and for sequential file I/O it is usually enough. Rings are attractive, but they solve a more general problem than mass-storage really needs.

So my practical advice is:

- keep the 4 kB shared page idea
- do not implement the ring logic in the CPLD
- strongly consider replacing the data ring with fixed-size double buffers
- let the MCU own all protocol semantics
- let the CPLD only execute fixed DMA bursts

That gets you most of the benefit without turning the card into a three-way arbitration problem.

If you want, I can sketch a concrete 4 kB layout based on double-buffered file transfers rather than a full ring.

User: You say the CPLD performs a 'bus master burst' - what is that exactly? Is it the data transfer? If so - how does it reach the MCUs internal RAM?

GitHub Copilot: Yes, in that sentence “bus master burst” meant the actual memory transfer on the Z80 side: the device takes the bus, presents addresses and control signals, and writes or reads a run of bytes to or from system RAM.

Your question is the right one: a CPLD cannot magically read the MCU’s internal RAM. Internal MCU SRAM is only visible inside the MCU unless the MCU explicitly exports the data somehow. So if the CPLD is the block performing the Z80 bus cycles, it needs a separate path to get the bytes.

That path can only be one of these:

1. MCU directly feeds the CPLD during the burst
The MCU writes bytes or words into a small register/FIFO interface in the CPLD, and the CPLD consumes them while driving the Z80 bus.
This works, but only if the MCU can keep up, or if the burst is short enough.

2. External transfer RAM or FIFO shared between MCU and CPLD
The MCU fills local RAM first. Then the CPLD reads that RAM and performs the Z80-side burst.
This is the cleanest separation, but it adds the hardware complexity you objected to.

3. MCU performs the bus transfer itself
In this case the MCU, not the CPLD, is what actually sources or sinks the data while bus mastering.
Then there is no “how does the CPLD reach MCU RAM?” problem, because it doesn’t. The MCU already has the data.
A CPLD could still help with bus arbitration or signal shaping, but it is no longer the transfer engine.

So yes: my earlier phrasing hid an important detail. If the payload is in MCU internal RAM, then either:
- the MCU must participate actively during the transfer, or
- the data must first be copied into some memory/FIFO the CPLD can see.

That is exactly why this partition is tricky.

For your design, the realistic options are:

1. MCU-only DMA engine
The MCU requests the bus and directly performs the reads/writes to Z80 memory.
Simplest hardware.
Harder timing problem.

2. MCU + small CPLD, but CPLD only handles arbitration/control
The MCU still provides address/data timing, or at least feeds the data path.
Middle ground, but not always worth it.

3. MCU + CPLD + shared buffer memory
Most robust hardware behavior.
Most complicated board design.

If your main concern is avoiding extra muxed RAM and keeping the board simpler, then the most honest conclusion is: the MCU probably has to be the actual DMA data mover. In that case, an MCU with:
- plenty of GPIO
- predictable timing
- decent SRAM
- maybe an external memory/peripheral bus for convenience
becomes more important than a CPLD-centric scheme.

So the corrected summary is:

- “bus master burst” = the actual sequence of memory read/write cycles on the Z80 bus
- if a CPLD performs that burst, it must get the bytes from somewhere it can see
- MCU internal RAM is not directly visible to the CPLD
- therefore you need either a feeder interface, external buffer memory, or the MCU doing the transfer itself

Given your stated preference for less hardware complexity, I would lean toward this architectural rule:
- MCU owns buffering and protocol
- MCU is the real DMA mover
- optional CPLD only assists with bus request/grant and safe bus isolation, not bulk data storage

If you want, I can next compare these two concrete approaches:
1. MCU directly writing Z80 RAM during bus hold
2. External dual-ported or shared transfer RAM page with no active burst copying at all

User: I actually like the CPLD idea and I understand that a (dual ported) RAM would be ideal, but I am trying not to over-engineer it. I am currently leaning towards a CPLD that performs the bus operations and DMA and has a dedicated/special/specific interface with the MCU. I mean would only take like 12 pins (max?) for a 2-way 8-bit data handshake...?

GitHub Copilot: Yes, that is a reasonable middle ground.

What you are describing is essentially:

- MCU handles storage, FAT, buffering, and protocol
- CPLD handles bus request/grant and Z80 memory read/write cycles
- MCU and CPLD talk over a small private byte-stream interface

That is not over-engineering. It is a fairly clean partition, and it avoids the worst part of the “full shared transfer RAM” design.

Your “about 12 pins” intuition is in the right range if the interface is narrow and handshake-based. For example:

- 8 data pins
- 1 direction bit, or separate read/write strobes
- 1 data valid / write strobe
- 1 ready / ack
- 1 optional packet-start / command-data select

That is already enough for a robust two-way link.

The main question is not pin count, but whether the MCU-to-CPLD link can feed data fast enough to justify the CPLD doing the Z80-side burst. There are two basic models.

1. Streaming interface
The MCU pushes or pulls bytes while the CPLD is in the middle of a DMA transfer.

This is the simplest interface electrically, but it means the CPLD is only as fast as the MCU can feed it. In that case the CPLD is mostly helping with timing cleanliness on the Z80 side, not making the transfer fundamentally faster.

2. Commanded burst with small local elasticity
The MCU first loads a small FIFO or holding buffer in the CPLD, then tells it:
- direction
- Z80 address
- length
- go

The CPLD performs as much of the burst as it can from that local buffer, while handshaking for refill or drain as needed.

This is usually the sweet spot. You do not need a full 4 kB dual-port RAM. Even a tiny elastic buffer, say 16 to 64 bytes, can decouple the MCU and the Z80 bus enough to simplify timing a lot.

So yes, a “special-purpose interface” is a good idea. I would make it packetized rather than a raw bidirectional bus.

A practical split would be:

Control path from MCU to CPLD:
- target Z80 address
- transfer length
- direction
- start
- maybe flags like auto-increment and interrupt-on-complete

Data path between MCU and CPLD:
- 8-bit data bus
- write strobe from source side
- read/consume strobe from sink side
- full/empty or ready/valid flags

That is cleaner than trying to build a symmetric “general bus” between them.

If you want to keep pins down, I would avoid a truly bidirectional 8-bit data bus unless you really need it. Two reasons:

- bidirectional buses cost you direction control and tighter timing discipline
- modern MCUs are often happier with separate unidirectional signals or a simple parallel write/read protocol

You can still do it bidirectionally, but from a design-risk standpoint, these are the options I’d rank:

1. 8-bit bidirectional data + 3 to 4 handshake/control pins
Lowest pin count, slightly trickier control.

2. 8-bit data path optimized for “mostly write into CPLD,” plus a few status registers read back separately
Very practical if storage reads dominate and writeback is less frequent.

3. 2 small unidirectional FIFOs
Best behavior, highest pin count.

For your use case, option 1 or 2 is likely enough.

The key design decision is this: do not make the CPLD parse rings or filesystem semantics. Let the CPLD see only transfer descriptors such as:

- source/destination mode
- base address
- byte count
- execute

Then the MCU can say:
- “write 512 bytes to Z80 RAM at page X offset Y”
- “read 128 bytes from Z80 RAM at address Z”

and the CPLD just does the cycles.

A few concrete recommendations:

- Put a small FIFO in the CPLD if it fits. Even 16 bytes helps.
- Keep the MCU-CPLD protocol fixed-length and simple.
- Support only linear bursts with auto-increment at the CPLD level.
- Let the MCU handle ring wrap, ownership, and command interpretation.
- Add a “pause/refill needed” state so the CPLD can stall between sub-bursts if its FIFO empties.
- Keep read-from-Z80 and write-to-Z80 symmetric if possible, but optimize write-to-Z80 first since that is the common storage-read path.

One subtle point: if the CPLD has no significant local buffering, calling it a “burst” can be misleading. It is then really a paced transfer engine. That is still useful. The win is that Z80 bus timing stays deterministic and isolated from MCU firmware jitter.

So my answer is: yes, that architecture is sane, and yes, roughly 10 to 14 signals is enough for a very workable private MCU-CPLD transfer interface. The real trick is to include just enough elasticity in the CPLD so the Z80 bus side and MCU side do not have to be cycle-locked.

A good first version would be:

- 8-bit shared data bus
- `DIR`
- `DATA_STB`
- `READY`
- `START`
- `DONE`
- optional `IRQ`

Then separate latched registers for:
- Z80 address
- transfer length
- mode

That keeps the CPLD simple and the board reasonable.

If you want, I can sketch a concrete signal list and a minimal MCU↔CPLD DMA protocol next.

User: yes, please do

GitHub Copilot: A workable first cut is to treat the MCU↔CPLD link as two planes:

- a slow control plane for transfer setup
- a narrow byte-stream plane for payload

That keeps the CPLD simple. It only needs to know “copy N bytes to or from Z80 memory starting at address A,” while the MCU handles all higher-level storage logic.

**Signals**

I would start with 14 to 16 signals total, depending on how symmetric you want reads and writes to be.

Minimal shared payload bus:
- `MCD[7:0]` : 8-bit data bus between MCU and CPLD
- `MDIR` : direction, `0 = MCU->CPLD`, `1 = CPLD->MCU`
- `MSTB` : source says data is valid
- `MACK` : sink accepted byte
- `MSTART` : marks start of a transfer
- `MDONE` : marks end of transfer / engine idle
- `MIRQ` : optional interrupt from CPLD to MCU

Control register interface:
- `CREG[1:0]` : register select
- `CWR` : write selected control register
- `CRD` : read selected status register

That is 8 + 8 = 16 pins if you count everything. You can trim it a bit if some signals are multiplexed.

If you want the absolute simplest version, drop `CRD` and make status visible on a few dedicated pins. Then you are around 14 pins.

**Register Set**

The CPLD only needs a few registers:

1. `ADDR0`
Low 8 bits of Z80 address.

2. `ADDR1`
Middle 8 bits of Z80 address.

3. `ADDR2`
High bits / page / flags.
Since your machine has paging, this should encode the physical destination context cleanly rather than pretending all RAM is flat.

4. `LEN0`
Low byte of transfer length.

5. `LEN1`
High byte of transfer length.

6. `CTRL`
Bits like:
- direction: `0 = write to Z80 RAM`, `1 = read from Z80 RAM`
- auto-increment enable
- assert interrupt on completion
- maybe memory cycle type if your bus distinguishes them

7. `STATUS`
Bits like:
- busy
- fifo empty
- fifo full
- done
- bus granted
- error / timeout

That is enough for a first implementation.

**Recommended Internal CPLD Structure**

Do not try to implement the full 4 kB ring logic in the CPLD. Internally, keep only:

- transfer registers
- a tiny FIFO, ideally 16 to 64 bytes
- a Z80 bus master state machine
- a small MCU-side handshake state machine

That is the right level of complexity for a CPLD.

**How A Write-To-Z80 Transfer Works**

This is the main storage-read case: MCU has read file data locally and wants it copied into Z80 RAM.

1. MCU fills `ADDR`, `LEN`, and `CTRL`.
2. MCU asserts `MSTART`.
3. CPLD requests the Z80 bus.
4. Once bus grant is active, CPLD begins consuming bytes from the MCU over `MCD[7:0]`.
5. For each accepted byte, CPLD performs one Z80 memory write cycle and increments address.
6. When `LEN` reaches zero, CPLD releases the bus and asserts `MDONE` or `MIRQ`.

The payload handshake is simply:

- MCU places byte on `MCD`
- MCU asserts `MSTB`
- CPLD latches byte when ready and pulses or asserts `MACK`
- MCU moves to next byte

That is easy to drive from firmware.

**How A Read-From-Z80 Transfer Works**

This is the storage-write case: device wants to fetch a block from Z80 RAM.

1. MCU fills `ADDR`, `LEN`, and `CTRL` with direction set to read-from-Z80.
2. MCU asserts `MSTART`.
3. CPLD requests the Z80 bus.
4. CPLD performs Z80 memory read cycles and pushes bytes toward MCU.
5. MCU accepts bytes using the same `MSTB/MACK` handshake, but with `MDIR=1`.
6. On completion, CPLD releases the bus and raises `MDONE`.

This gives you symmetry without needing separate buses.

**Recommended Handshake Semantics**

Use a ready/valid style handshake, even if you name the signals differently.

For `MCU -> CPLD`:
- MCU drives byte and raises `MSTB`
- CPLD raises `MACK` when consumed
- MCU drops `MSTB` and advances

For `CPLD -> MCU`:
- CPLD drives byte and raises `MSTB`
- MCU raises `MACK` when consumed
- CPLD drops `MSTB` and advances

That lets one pair of handshake lines work in both directions.

**Why A Tiny FIFO Helps**

Without any FIFO, the CPLD must wait on nearly every byte for the MCU. That still works, but bus hold time increases.

Even a 16-byte FIFO helps because the sequence becomes:

- MCU preloads a few bytes
- CPLD takes the bus and writes a short burst
- MCU refills while CPLD drains
- if FIFO empties, CPLD pauses locally, not by losing state

So the system behaves much better even with a very small amount of elasticity.

**A Minimal Protocol Example**

Write 512 bytes to Z80 RAM:

1. MCU writes:
- `ADDR = destination`
- `LEN = 512`
- `CTRL = write_to_z80 | autoinc | irq_on_done`

2. MCU asserts `MSTART`.

3. CPLD:
- sets `busy`
- requests bus
- waits for grant
- starts draining incoming bytes into memory writes

4. MCU streams 512 bytes over `MCD` using `MSTB/MACK`.

5. CPLD:
- decrements internal count
- releases bus at zero
- sets `done`
- optionally asserts `MIRQ`

**What The CPLD State Machine Actually Does**

The core states are simple:

1. `IDLE`
Wait for `MSTART`.

2. `REQ_BUS`
Assert bus request, wait for CPU release/grant.

3. `TRANSFER`
For each byte:
- if direction is MCU->Z80, wait for input byte then issue memory write cycle
- if direction is Z80->MCU, issue memory read cycle then present byte to MCU
- increment address
- decrement count

4. `COMPLETE`
Release bus, raise done/irq, return to idle.

That is a good CPLD problem. It avoids parsing rings, file handles, or variable-sized descriptors.

**Where The 4 kB Shared Page Fits**

Your 4 kB page can still be the software-visible transport area, but the CPLD does not need to understand its internal structure.

The MCU can interpret:
- command ring
- completion ring
- data buffer ownership

Then it tells the CPLD only:
- move bytes from my local buffer to Z80 page offset X
or
- fetch bytes from Z80 page offset X into my local buffer

That keeps the smart part in firmware and the deterministic part in logic.

**My Recommendation For Rev 1**

I would build rev 1 around:

- 8-bit bidirectional data bus `MCD[7:0]`
- `MDIR`
- `MSTB`
- `MACK`
- `MSTART`
- `MDONE`
- optional `MIRQ`
- 5 to 7 simple control/status registers
- a 16-byte or 32-byte FIFO inside the CPLD if it fits

That is small enough to be realistic and structured enough to grow.

If you want, I can next turn this into one of two concrete artifacts:

1. a pin-level signal table with exact direction and meaning for each pin
2. a register map and step-by-step firmware/CPLD transaction sequence for `DMA write`, `DMA read`, and `status polling`

User: The z80 program should tell the smart-device where it wants the data written, or where it has prepared the data to be read by the smart device/mcu. The command-plane of the protocol communicates what the operation is and for instance a file name etc.
I am not sure if I want the commands to be just another DMA with predefined structures or some sort of IO driven mechanism where the CPLD implemens some IO ports and stores address, length and operation etc. Other metadata (file name) will then be a problem. But there should be a trigger that the z80 app can set/send that tells the smart-device that it can do its thing.
Interrupt on done is a must.
Ideally I would also want the z80 program to be able to setup a device-to-device exchange but that can wait.

GitHub Copilot: The cleanest answer is a hybrid, not “all DMA” or “all I/O”.

Use I/O for control and triggering, and use DMA-visible memory for everything variable-sized. That gives you a simple hardware model and avoids turning file names and long metadata into awkward port traffic.

What I would recommend is:

1. The Z80 builds a command descriptor in RAM.
2. The descriptor contains:
- operation
- data buffer address
- data length
- metadata pointer
- metadata length
- flags
- request id or tag

3. The Z80 pokes one or two I/O registers in the smart-device:
- descriptor address
- `GO` / doorbell

4. The smart-device raises DMA, fetches the descriptor, then fetches any extra metadata such as the filename from the pointer in the descriptor.

5. When done, it writes status back to a completion area or updates the descriptor, then interrupts the Z80.

That is the best fit for what you described.

Why this is better than pure I/O commands:
- filenames and paths stay in normal RAM, so they can be arbitrary length
- you avoid designing a complicated port-streaming protocol for metadata
- the CPLD only needs a few I/O registers, not a full command parser
- the same mechanism scales later to device-to-device transfers

Why this is better than “commands are just another DMA blob” with no I/O:
- you still need a clean trigger
- you still need status/ownership bits somewhere
- a tiny I/O doorbell interface is much simpler than polling memory blindly
- reset/error/abort becomes easier

So I would make the command plane look like this:

I/O registers:
- `CMD_DESC_LO`
- `CMD_DESC_HI`
- `CMD_DESC_PAGE` or bank/page selector if needed
- `CONTROL`
- `STATUS`
- `IRQ_ACK`

And let `CONTROL` contain things like:
- `GO`
- `ABORT`
- `RESET`

Let `STATUS` contain:
- `BUSY`
- `DONE`
- `ERROR`
- maybe `IRQ_PENDING`

Then put the real command payload in RAM.

A good first descriptor could be fixed-size, something like:

```c
struct DeviceCommand {
    uint8_t opcode;
    uint8_t flags;
    uint16_t request_id;

    uint32_t data_addr;
    uint16_t data_len;

    uint32_t meta_addr;
    uint16_t meta_len;

    uint32_t result_addr;
    uint16_t result_len;

    uint8_t status;
    uint8_t error;
};
```

The exact widths depend on how your page/bank system is encoded, but the structure is the important part.

That gives you a clean split:

- `data_addr/data_len`: actual file payload buffer
- `meta_addr/meta_len`: filename, path, open mode, seek info, whatever extra command data is needed
- `result_addr/result_len`: optional return payload for things like directory listings or stat data

For example:

`OPEN`:
- `opcode = OPEN`
- `meta_addr -> "SYS/CONFIG.TXT\0"`
- `meta_len = filename length`
- `data_addr = 0`
- result written into descriptor or result buffer

`READ`:
- `opcode = READ`
- `data_addr = destination buffer in Z80 RAM`
- `data_len = requested bytes`
- metadata may be empty if using an already-open handle

`WRITE`:
- `opcode = WRITE`
- `data_addr = source buffer in Z80 RAM`
- `data_len = bytes to write`

That avoids inventing separate special cases for “commands with strings” versus “commands with data”.

The CPLD role then becomes much simpler:
- expose a few I/O registers
- latch the descriptor pointer when `GO` is written
- notify the MCU
- optionally help fetch the descriptor or perform DMA bursts
- assert interrupt on completion

The MCU role:
- interpret the descriptor
- fetch any extra metadata via DMA
- do FAT/filesystem work
- move file data to/from the specified buffer
- update completion status
- trigger interrupt

That is a much cleaner partition than making the CPLD understand filenames or command syntax.

For completion, I would strongly prefer:
- interrupt on done
- plus a completion status field in memory

Do not rely on interrupt alone. The interrupt is the wakeup, but the descriptor/result area is the truth. That makes retries, debugging, and future multitasking much cleaner.

On the “where should the operation be set” question: use the descriptor, not a port. The port should just be the trigger. In other words:

- operation code lives in RAM descriptor
- I/O port says only “command at address X is ready”

That is the simplest model.

For future device-to-device exchange, this same model extends nicely. Later you can define a descriptor whose source or target is not “CPU RAM” but “device endpoint”. For example:
- source device id
- destination device id
- shared buffer descriptor
- command chaining

You do not need to solve that now, but this descriptor-based design does not block it.

My recommendation for rev 1 is therefore:

1. Use I/O only as doorbell/control/status.
2. Put all real command content in a fixed-size command descriptor in RAM.
3. Put variable-length metadata like filenames in separate RAM buffers referenced by the descriptor.
4. Use DMA for descriptor fetch, metadata fetch, and payload transfer.
5. Signal completion with both an interrupt and a status/result update in RAM.

That gives you simple hardware, flexible commands, and a path to future device-to-device operations.

If you want, I can next sketch a concrete rev-1 command descriptor and the minimum I/O register set for `OPEN`, `READ`, `WRITE`, and `CLOSE`.

User: Good. That was the way I was thinking too. I just wanted to see if you came up with something new/different.
Here is a document of the previous version/proof-of-concept on this. It is not how it is going to be persee, but the same ideas are in there, I think

GitHub Copilot: The ideas in storage device.md are still good. The document is internally consistent around the core model:

- Z80 sets up intent and buffer locations
- smart device owns filesystem and media details
- bulk data moves through DMA
- interrupt-on-done is the synchronization point
- sequential transfers can benefit from prefetch

That is still the right architecture for your current bus concept.

What I think is still strong in that document:

- The split between command/control and bulk transfer is good.
- Letting the Z80 provide source or destination buffer addresses is the right abstraction.
- Keeping filesystem state inside the device is the right simplification.
- The `Sequential` idea is useful. It gives the device permission to optimize without changing the programming model.
- Returning metadata as a structured stream is also a good direction.

What I would change for a new version:

- I would move away from “command buffer registers” containing rich command content and instead put command descriptors in RAM, with I/O only used as the doorbell/control path.
- I would avoid making `BlockIndex` the main trigger mechanism. It works, but it leaks the block-transfer implementation into the software contract too much.
- I would not bake in IDE sector-size assumptions at the protocol level unless you know the device will always stay IDE/CF. The device abstraction should be file-oriented, not 512-byte-device-oriented.
- I would separate “command metadata” from “payload buffer” more explicitly than the old document does.
- I would treat status in RAM as authoritative, with the interrupt only as notification.

So if I were evolving this design, I would keep the same idea but reframe it like this:

- I/O registers:
  - descriptor pointer
  - `GO`
  - `STATUS`
  - `IRQ_ACK`
  - maybe `ABORT`
- RAM descriptor:
  - opcode
  - flags
  - data buffer address/length
  - metadata pointer/length
  - result pointer/length
  - status/error/request id

That is basically the same architecture as your older proof-of-concept, just with a cleaner boundary between “tell device what to do” and “where the variable data lives”.

The biggest conceptual improvement over the old version is this:
the host should submit operations, not blocks.

The device may internally process the operation in blocks, prefetch, double-buffer, or stall as needed, but the Z80-facing API should preferably be:
- open
- read into this buffer
- write from this buffer
- close
- list
- delete

rather than:
- here is block 0
- here is block 1
- here is block 2

You can still support continuation under the hood, but if you expose block numbering too directly, the host starts managing device internals.

So my read is: yes, the old document contains the right ideas, and it validates the direction you are now converging on. The main thing I would update is the interface shape, not the architecture.

If you want, I can turn this into a cleaned-up rev-2 design note in storage device.md that keeps the good ideas but rewrites the protocol around:
1. RAM-based command descriptors
2. I/O doorbell/status registers
3. interrupt-on-completion
4. optional sequential/prefetch flags

User: Yes, good points, thanks. Continuation will almost certainly be needed. I imagine there will always be a file bigger than the buffer in memory...
If we keep all the state of a transfer in the descriptors than the operations can even be interleaved. That would be benificial because we can have multiple prgrams running. The IO interfacing will be very minimal: the address (2 byte) and a 'go' that also could double as an abort and anything else we might need (based on the value).
The IRQ is a flag in the descriptor and the smart device updates the descriptor just before it raises the interrupt.
something like that...

GitHub Copilot: Yes, that is a strong direction.

The key improvement is that the descriptor becomes the durable source of truth for an operation, not just a transient setup block. Once you do that, continuation and interleaving stop being special cases and become the normal model:

1. Z80 fills a descriptor.
2. Z80 writes the descriptor address to the device and sends a command value such as GO.
3. The smart device owns execution from there.
4. The device updates the descriptor state as progress is made.
5. On completion or notable progress, it updates the descriptor first, then raises the interrupt if requested.

That gives you a very clean contract.

A few points I would lock in early:

1. Descriptor address probably needs more than 2 bytes unless you guarantee the descriptor always lives in a fixed visible page.
If the smart device DMA sees the current MMU mapping exactly as the Z80 does, then 16-bit may be enough.
If descriptors may live in arbitrary physical pages, you likely want a page or bank field too.

2. The I/O interface can stay extremely small.
A very workable model is:
- descriptor low
- descriptor high
- optional descriptor page
- command register

The command register values could be:
- 0 = no-op
- 1 = submit
- 2 = abort current descriptor
- 3 = acknowledge interrupt
- 4 = reset device

That is enough for a first version.

3. The descriptor should have an explicit state machine.
Not just busy and done.
I would want states like:
- free
- submitted
- accepted
- active
- waiting
- partial
- done
- aborted
- error

That makes interleaving and recovery much easier.

4. Continuation should be device-managed, but visible.
In other words, the host submits a read or write request for some total length, and the device advances fields such as:
- bytes completed
- next data pointer
- remaining length
- current status

The host should not have to manually count blocks unless you deliberately want a low-level mode.

5. Abort should be descriptor-specific.
That matters once operations can interleave.
You do not want a vague global abort if multiple programs may have pending work.

6. The interrupt flag in the descriptor is a good idea.
I would still keep a device status bit too, because it helps with polling and debugging.
The descriptor remains authoritative, but a tiny hardware status bit is useful.

The biggest design choice still open is whether one descriptor represents:
- one complete high-level operation, with the device internally continuing as needed
or
- one transfer slice, where the host resubmits continuations

Given what you just said about multitasking and interleaving, I would choose the first one. Let one descriptor represent the whole operation. The device can then pause, resume, prefetch, and interleave internally. That is a much cleaner multitasking model.

A practical descriptor shape would probably include:

- opcode
- flags
- owner or task id
- data address
- data length requested
- metadata address
- metadata length
- bytes completed
- current phase
- result code
- interrupt-on-completion flag
- maybe a request id or sequence number

A sequence number is worth considering. It avoids ambiguity if software reuses a descriptor slot and an old interrupt arrives late.

So overall: yes, this is converging well. Minimal I/O, descriptor-owned state, interrupt-after-descriptor-update, and device-managed continuation is the right combination. It gives you a small hardware surface and still leaves room for interleaving and later device-to-device work.

If you want, I can next sketch a concrete descriptor layout and a small command/state enum set that fits this model.

User: descriptors can have a type-id (command id). specific devices required specific descriptors all with a unique type-id. So we'll start with a high abstraction 'one file at a time'. If I need something lower level, I'll add additional descriptor-types that cover that.
Yes for interleaving we need a work-id/tag for job that was submitted to be able to reference it later; for abort and perhaps interrupt. 
Although the way interrupts work now, the device driver in the os probably has to poll the device for the tag that had an event (and the type of event if we're at it). We also might want the smart device to report progress...? Don't know yet.

GitHub Copilot: Yes. That is the right way to generalize it.

A common descriptor header plus a type-specific payload gives you three useful properties at once:

- one submission mechanism for all smart devices
- device-specific descriptor bodies where needed
- room to add lower-level operations later without disturbing the higher-level file model

I would make every descriptor start with the same small header, something like:

- type-id
- total descriptor length or version
- work-id / tag
- owner or task-id
- flags
- state
- result / error
- event mask
- bytes done or progress field

After that, the body is defined by the type-id. That keeps the hardware and OS driver generic while letting each device define its own command shape.

For interrupts, I would not make the OS poll every live descriptor to discover which tag fired. That scales badly once interleaving starts. A better model is:

- the device raises one IRQ line meaning “one or more events pending”
- the OS driver reads a very small event source from the device
- that event source returns at least:
  - work-id / tag
  - event type
  - maybe descriptor address or type-id
- then the driver looks at the descriptor if it needs more detail

So the interrupt does not carry the whole meaning. It just says “go read the next event.” That event channel can be:

1. a tiny I/O event register pair
Simplest hardware. The driver reads the current event and acknowledges it.

2. a small event FIFO inside the device
Better if multiple completions can happen close together.

3. an event queue in RAM
Most flexible, but more moving parts.

For rev 1, I would seriously consider option 1 or 2. One IRQ plus a tiny event FIFO is a good sweet spot.

A useful event record would be:

- tag
- event kind
- status / error
- optional progress snapshot

Event kinds could be:

- accepted
- progress
- buffer-ready
- completed
- aborted
- error

That way your IRQ model becomes very clean:
- descriptor is the authoritative state
- IRQ means “events available”
- event record tells the driver which work-id changed
- driver inspects or updates the corresponding descriptor

On progress: yes, I think you should allow for it, but make it optional and cheap.

I would not force periodic progress interrupts. That can become noise quickly. Better to support:

- a progress field in the descriptor, such as bytes completed
- an optional progress event flag if the submitter asks for it
- perhaps only generate progress events on meaningful boundaries, like every buffer filled, every 4 kB, or every phase change

That gives you room for user feedback later without burdening the common path.

One practical refinement: distinguish between state and event.

State is persistent:
- submitted
- active
- waiting
- done
- error
- aborted

Event is transient:
- started
- more data available
- progress threshold reached
- completed
- faulted

That distinction makes the driver logic much easier.

So the model I would recommend is:

- common descriptor header for all devices
- type-id selects descriptor body
- work-id/tag uniquely identifies the submission
- single IRQ line means “pending event(s)”
- device exposes an event readout path so the driver does not have to scan descriptors
- descriptor contains durable state and optional progress counters
- event stream contains the transient notifications

That is a solid foundation for interleaving and later expansion.

If you want, I can next sketch:
1. a common descriptor header
2. a minimal event record format
3. a simple IRQ/event-handling flow for the OS driver
