I need to communicate hi-level graphics operations to a video card. I want the protocol to be as simple as possible. Data exchange between CPU and "GPU" is via DMA and some IO. Target is tile-based games and a simple window-manager. Suggest a protocol/language.

For a simple, DMA-friendly protocol targeting tile-based games and a window manager, I'd recommend designing a command buffer architecture rather than using an existing graphics language. Here's my thinking:

Protocol Design Approach
Keep it minimal and binary. You want to avoid parsing complexity on the GPU side. A fixed-size command buffer with simple opcodes is ideal for DMA transfers. Each command should be a small, fixed-size structure (e.g., 16–32 bytes) that the GPU can process sequentially without complex parsing.

Suggested Command Set
A bare-bones instruction set might include:

FILL_RECT: Fill a rectangular region with a solid color (opcode + x, y, width, height, color)
COPY_TILE: Copy a tile from VRAM to a destination (source tile index, dest x/y)
BLIT: Copy a region from one VRAM location to another
SET_PALETTE: Update color palette entries
VSYNC_WAIT: Synchronization point
This is perfect for tile-based games because you're essentially just moving tile graphics around and filling areas.

Implementation Strategy
Structure it as:

Fixed opcode size (e.g., 8-bit or 16-bit identifier)
Fixed payload size (pack parameters tightly)
DMA-friendly: CPU writes commands to a ring buffer in shared memory; GPU reads and executes sequentially
No variable-length data: Everything is predictable for DMA
Why Not Use Existing Languages?
OpenGL/Vulkan: Far too complex for simple tile graphics; massive overhead
Custom bytecode: Could work, but you don't need the flexibility
Direct register writes: Possible but harder to manage; a command buffer is cleaner
A simple binary protocol with 16–32 byte commands is what you want. Design it specific to your hardware capabilities, keep the GPU side dumb (just execute commands in order), and let the CPU handle all the logic. This minimizes latency and complexity while being trivial to DMA.

What constraints do you have on command buffer size, GPU memory, or tile resolution?

Would like to keep buffer < 4k - that is one memory page that can be shared between CPU/app and video card.
GPU memory is undetermined. I was thinking to make it pretty big to also store app assets that can be easily referenced in the commands (instead of pumping over bytes each time). Screen resolution is max 800x600. We're dealing with an 8-bit CPU (Z80) so an 8x8 tile sounds reasonable?

Perfect constraints. A 4KB command buffer with 8×8 tiles on an 800×600 screen is very workable. Here's a practical protocol:

Command Buffer Layout
Keep the buffer simple:

Command queue: Fixed-size commands (16 bytes each = 256 commands per 4KB buffer)
Opcode (1 byte) + parameters (15 bytes) per command
This gives you room for ~250 commands per frame, which is plenty for a window manager and tile-based game updates.

Minimal Instruction Set
Opcode	Name	Parameters	Purpose
0x01	TILE_BLIT	dest_x (2B), dest_y (2B), tile_id (2B), flags (1B), unused (8B)	Copy 8×8 tile from GPU VRAM to screen
0x02	FILL_RECT	x (2B), y (2B), width (2B), height (2B), color (1B), unused (6B)	Fill rectangular area with solid color
0x03	SET_SCROLL	offset_x (2B), offset_y (2B), unused (11B)	Set viewport scroll offset
0x04	PALETTE_SET	index (1B), color (3B for RGB), unused (11B)	Set single palette entry
0x05	VSYNC_WAIT	unused (15B)	Wait for vertical sync (GPU stalls)
0x06	COPY_VRAM	src_id (2B), dest_vram_addr (2B), size (2B), unused (9B)	Copy asset from CPU to GPU VRAM
0x00	END	unused (15B)	Mark end of command stream
GPU VRAM Strategy
Since GPU memory is flexible, organize it:

Tile sheet area: 64KB for 1,024 tiles (8×8 × 8bpp = 64 bytes/tile)
Framebuffer area: 480KB for 800×600 in 8-bit color
Palette area: 256 bytes (256-color palette)
Remaining: Free space for dynamic assets, scrolling buffers, etc.
Tile IDs in TILE_BLIT commands are just indices into your tile sheet—no data pumped over.

Why This Works for Z80
8-bit CPU: Commands fit naturally in memory; 16-byte structures are easy to construct
DMA: CPU writes commands sequentially; GPU reads and executes in order
Tile-based games: TILE_BLIT is your workhorse (99% of game updates)
Window manager: FILL_RECT handles backgrounds; TILE_BLIT handles widgets/icons
Asset streaming: COPY_VRAM lets you load new tiles/sprites on demand without clogging the command buffer
Practical Example
A frame rendering a 100×75 tile map would use ~7,500 TILE_BLIT commands, but you can optimize by:

Only sending dirty tiles (changed since last frame)
Using SET_SCROLL instead of rewriting every tile position
Batching similar operations
Does the 256-command-per-4KB limit feel tight, or would you want to optimize further? You could shrink commands to 8 bytes each (doubling capacity) if you compress parameters creatively.

I was hoping to find some way to have the app list out an entire screen in commands in memory. The GPU would that simply execute those commands in order to redraw the screen (implemented in immediate-mode + double buffers). But I don't know how to organize the app-video-cmd-memory in such a way that it doesn't become a nightmare for the app-dev - other than perhaps a linked list structure. The app should be able to easily add/remove/replace commands to reflect changes in the screen...

You're describing what amounts to a display list, and for a 4KB constraint with an 8-bit CPU, a linked list structure is actually the right choice. Here's how to make it developer-friendly:

Linked List Command Buffer Design
Memory Layout
Divide the 4KB buffer into two regions:



[0x0000 - 0x0FFF] = 4096 bytes total
├─ [0x0000 - 0x0800] = Command pool (2048 bytes, ~128 commands @ 16 bytes each)
└─ [0x0800 - 0x0FFF] = Free space for dynamic allocation
Each command node contains:



Offset  Size  Field
0x00    2     next_ptr (pointer to next command, 0xFFFF = end of list)
0x02    1     opcode
0x03    13    parameters (flexible per opcode)
This gives you 16-byte nodes, and the next_ptr lets the app build arbitrary command chains.

App-Friendly API
Provide simple C macros/functions for app developers:

c


// Initialize the display list
void display_list_init();

// Add a command to the end of the list
void add_tile_blit(uint16_t x, uint16_t y, uint16_t tile_id);
void add_fill_rect(uint16_t x, uint16_t y, uint16_t w, uint16_t h, uint8_t color);

// Replace a command (useful for animations, UI updates)
void replace_command(uint16_t node_ptr, uint8_t opcode, void *params);

// Remove a command
void remove_command(uint16_t node_ptr);

// Get pointer to last added command (for later modification)
uint16_t last_command_ptr();

// Clear entire list
void clear_display_list();
Behind the scenes, you maintain:

Head pointer: First command in the chain
Tail pointer: Last command (for fast appends)
Free list: Linked list of unused nodes (for fast allocation/deallocation)
Why Linked Lists Work Here
O(1) append: Add commands to the tail without reorganizing
O(1) removal: Remove/replace a command by repointing its predecessor
No defragmentation nightmare: Free nodes form their own linked list; reuse them
Predictable memory: You can pre-allocate all 128 nodes upfront; no dynamic allocation surprises
GPU-friendly: GPU just follows the next_ptr chain; doesn't care about layout
Simple Example: Window Manager UI Update
c


// Initial frame: draw a window
clear_display_list();
add_fill_rect(10, 10, 200, 150, 0);     // background
add_tile_blit(15, 15, TILE_WINDOW_TL);  // corner
// ... more tiles for window border
uint16_t button_ptr = last_command_ptr();
add_tile_blit(50, 50, TILE_BUTTON_UP);  // button

// User clicks button: change its tile
replace_command(button_ptr, OPCODE_TILE_BLIT, 
                &(tile_blit_params){50, 50, TILE_BUTTON_DOWN});

// Next frame: GPU executes updated command chain, button appears pressed
Implementation Details
Free list management (allocate new nodes):

c


uint16_t alloc_node() {
    if (free_list_head == 0xFFFF) return 0xFFFF; // out of memory
    uint16_t node = free_list_head;
    free_list_head = *(uint16_t*)(buffer + free_list_head); // next free node
    return node;
}
Deallocation (return nodes to free list):

c


void free_node(uint16_t node) {
    *(uint16_t*)(buffer + node) = free_list_head;
    free_list_head = node;
}
Memory Efficiency
With 128 nodes @ 16 bytes = 2,048 bytes used, you have 2,048 bytes of headroom for dynamic data (strings, dynamic tile lists, etc.). For most simple games/UIs, 128 commands per screen is more than enough.

If you need more commands, you can shrink commands to 8 bytes (opcode + 7-byte params) and get 256 nodes, but 16-byte commands are cleaner for Z80.

Does this feel manageable for your app developers? The key insight is that the app doesn't care about the buffer's physical layout—it just calls add_tile_blit() and lets the library handle node allocation and linking.

Yes - treat it as an allocator ;-) Cool idea. I can always add another 4k page if needed (I have plenty of memory).
The GPUs DMA will copy (as fast as the SRAMs will go) the entire block in one go - and sort out what it has to do on it's own. That way the CPU is only paused for a short while. There will be an IO port on the GPU that tells it where to look and when to start looking (or stop). Then it'll raise an interrupt to let the app know it is done.
Yes, that would totally work.

Excellent! You've got a clean, efficient architecture. Here's how the handshake would work:

CPU-GPU Protocol
IO Port Interface (CPU writes to GPU):

Port	Purpose
0xF0	Command buffer address (high 8 bits)
0xF1	Command buffer address (low 8 bits)
0xF2	Control: write 0x01 to start DMA, 0x00 to stop
GPU Behavior:

CPU writes address of command buffer (4KB page) to ports 0xF0/0xF1
CPU writes 0x01 to port 0xF2 (start signal)
GPU DMA copies entire 4KB block into its local cache at SRAM speed
GPU's command executor walks the linked list (from head pointer at buffer offset 0x00), executing commands in order
When it hits END (0x00 opcode or 0xFFFF next_ptr), rendering is complete
GPU raises interrupt to CPU (CPU can proceed immediately; doesn't wait for rendering)
This gives you minimal CPU stall (just the DMA copy time) and asynchronous rendering—the CPU can start building the next frame's command buffer while the GPU is drawing the current one.

Key Advantages
Decoupled: CPU and GPU work independently after handshake
Simple: No complex protocol; just "here's the address, go"
Scalable: Add more memory pages without changing the protocol
Double-buffering friendly: CPU builds frame N+1 while GPU renders frame N
Z80-friendly: Minimal interrupt handling, predictable latency
One small tip: consider reserving the first 2 bytes of the command buffer as a version/metadata field (or keep it as your head pointer). This lets you validate the buffer hasn't been corrupted and gives you room to extend the format later without breaking compatibility.

You've got a solid design. Ready to implement it?

No - now I have to design the hardware for the GPU  ;-)

Ha! Well, you've got the easy part done—the protocol is the hard part. Now you get to build the beast that executes it. 😄

You're looking at:

High-Level GPU Architecture
DMA Controller

Listen on those IO ports (0xF0, 0xF1, 0xF2)
Fetch the 4KB command buffer into local SRAM
Signal when done
Command Executor

Walk the linked list following next_ptr pointers
Decode opcodes and dispatch to functional units
Handle VSYNC_WAIT synchronously (stall until next vsync)
Functional Units

Tile Blitter: Copy 8×8 tiles from VRAM to framebuffer (the workhorse)
Rectangle Filler: Fast fill using color/pattern
Palette Manager: Swap color definitions on the fly
Framebuffer Controller: Double-buffered 800×600 display
Timing/Sync

Vsync interrupt to CPU when frame is done
Maybe a "GPU busy" status flag so CPU can poll if needed
Implementation Considerations
SRAM size: 64KB+ for tile sheets, palette, framebuffer swap space (480KB for full 800×600 is a lot—consider tiling the framebuffer or using a smaller res internally)
Pixel clock: Depends on your display technology, but standard VGA timings are a starting point
Tile blitter bandwidth: Your bottleneck. Make sure it can keep up with your command rate
This is where you decide: FPGA with Verilog/VHDL, or hardcoded RTL? Either way, you're now in the weeds of hardware design—state machines, memory controllers, timing diagrams, the whole nine yards.

What's your target technology? (FPGA, custom silicon, discrete logic?)

I was thinking of a small (5v tolerant) CPLD for Z80 bus interaction and DMA impl. A local RAM buffer and an MCU for the smarts and interfacing with the display. Not sure yet what the target will be: VGA/HDMI or just an LCD display (800x480) I have laying around (SDD1963)... If I go with VGA/HDMI the CPLD will get to do stuff there too

Smart approach. A CPLD + MCU split is practical for this scale. Here's how I'd think about it:

CPLD Role (Z80 Bus Arbiter + DMA Engine)
The CPLD is your glue logic and control plane:

Z80 bus interface: Decode address/chip-selects, handle IO port writes (0xF0–0xF2)
DMA controller: Initiate block transfers from CPU memory to local SRAM
Memory arbitration: Multiplex SRAM access between CPU (via Z80 bus) and MCU (internal)
Vsync interrupt line: Pull CPU interrupt when MCU signals frame complete
Decoding for display interface: If VGA, generate sync signals; if LCD, control SDD1963 protocol
The CPLD is 5V tolerant, so Z80 bus voltage compatibility is handled. It keeps the MCU isolated from bus timing complexity.

MCU Role (Command Executor + Display Driver)
The MCU is your renderer and display controller:

Command list walker: Fetch commands from local SRAM, decode opcodes, dispatch
Tile blitter logic: Implement the tile copy (8×8 at a time)
Rectangle fill: Software fill or use MCU's built-in hardware (if available)
Display interface: Drive the SDD1963 (or VGA DAC if you go that route)
Timing: Generate pixel clocks, handle vsync
Architecture Sketch


Z80 CPU ←→ CPLD ←→ Local SRAM (4KB command + tile cache)
                ↓
              MCU (reads SRAM, executes commands)
                ↓
          [LCD/VGA Driver]
                ↓
            Display
Decision: LCD vs VGA/HDMI
LCD (SDD1963 controller) — Simpler route:

SDD1963 handles sync/timing for you
MCU just writes pixel data via parallel/SPI interface
CPLD only needs to handle Z80 ↔ SRAM arbitration
Tighter integration, fewer moving parts
VGA/HDMI — More complex but flexible:

CPLD generates VGA sync signals (needs precise timing)
MCU still renders to framebuffer
HDMI adds serialization (might need a dedicated HDMI transceiver IC)
More overhead on CPLD (timing-critical)
For an 800×600 8-bit system, LCD with SDD1963 is the practical choice. You get a working display faster, and the MCU isn't fighting for bandwidth with VGA timing.

MCU Selection
You'll want something with:

Enough RAM: 64KB+ (tile cache, framebuffer workspace)
Fast enough: 100+ MHz ideals (to keep up with tile blitting)
SPI/parallel I/O: For display interface
Interrupt support: For DMA complete signals from CPLD
STM32 or similar Cortex-M would be overkill but reliable. An ATmega328P or similar might be tight on RAM. Consider an STM32F4 or nRF52 if you want headroom.

Real talk: The tile blitter is your performance bottleneck. An 8×8 tile at 8bpp is 64 bytes. If you're redrawing a full 800×600 screen (100×75 tiles = 7,500 tiles), that's 480KB of data moved per frame. At 60 FPS, you need ~28 MB/s throughput. Make sure your SRAM speed and MCU bandwidth can handle it (or use dirty-tile culling to minimize redraws).

What MCU/CPLD combo are you leaning toward?

CPLD is the Xilinx XC9500XL-series. I use a XC95288XL on the main CPU board (currently in proto). MCU not sure yet. Perhaps an old Pi-Pico (RP2040) that has specific programmable IO I want to check out -or a STM32F4xx series (401/411). ATmega's are too slow I think..? I have an ATmega1284P on the main board for some additional serial IO and system-services...

Solid choices. The XC95288XL is a workhorse CPLD—plenty of logic for bus arbitration + DMA + display timing. And you've got experience with it already, which is gold.

MCU Comparison for Your Use Case
Aspect	RP2040	STM32F4xx	Why It Matters
Core Speed	133 MHz	168 MHz (F401) / 200 MHz (F411)	Both handle tile blitting comfortably
RAM	264 KB	96 KB (F401) / 128 KB (F411)	RP2040 has breathing room; F401 tight
PIO (Programmable IO)	2 × 32-bit, 4 state machines each	None—GPIO only	RP2040 wins for custom protocols (SDD1963, VGA timing)
Peripherals	SPI, I2C, UART, ADC	SPI, I2C, UART, ADC, timers	F4 has more flexible timers
Ecosystem	MicroPython friendly, good docs	Extensive HALs, industrial support	RP2040 easier to prototype; F4 mature
Display Timing	PIO can generate pixel clocks/sync	Software bit-banging or timer PWM	RP2040's PIO is perfect for this
My Take
RP2040 is the better fit for your project, specifically because of PIO (Programmable IO). Here's why:

RP2040's PIO Advantage
If you go LCD (SDD1963), you can use PIO to handle the timing/protocol without bogging down the ARM core. For example:

State machine 0: Generates pixel clock + write signals to SDD1963
State machine 1: Handles command/data framing
Meanwhile, the ARM core happily executes your tile blitter logic
If you later switch to VGA, PIO can even generate sync signals (HSYNC/VSYNC) while the ARM core renders.

This is huge for an 8-bit retro system—it's exactly what PIO was designed for.

STM32F4 Alternative
The F4 is rock-solid and has more mature libraries. If you go this route, you're bit-banging or using the timer peripherals to synchronize display I/O. It works, but you're doing more in software, which eats CPU cycles.

Practical Setup
RP2040 + XC95288XL architecture:



Z80 ←→ XC95288XL ←→ Local SRAM (4KB command buffer)
                ↓
              RP2040 (command executor + PIO display driver)
                ↓
            SDD1963 LCD Controller (via PIO)
                ↓
            800×480 LCD Display
CPLD handles:

Z80 bus decoding (IO ports 0xF0–0xF2)
DMA from Z80 memory → SRAM
Interrupt signal back to Z80
RP2040 handles:

Read commands from SRAM, execute them
Tile blitter (8×8 copies into framebuffer workspace)
PIO-driven SDD1963 protocol (or VGA sync if you pivot)
One Caveat
The F401 RAM is tight (96 KB) if you're storing a full framebuffer + tile cache + command buffer. The F411 or RP2040 have more headroom.

Since you've already got the XC95288XL board working, I'd prototype with the RP2040 first. Its PIO is genuinely useful here, and if the ecosystem disappoints, falling back to an F4xx is trivial—the interface layer is thin.

Have you written any RP2040 PIO code before, or would this be a first rodeo?

The immediate implementation of the GPU does not require storing a frame in ram. You walk the command list and perform each operation on the spot outputting the pixels directly to the display...?

Ah, you're absolutely right—I overcomplicated it. No framebuffer needed at all.

Immediate-Mode Rendering
You walk the command list once per frame, executing each operation directly to the display as you go:



For each vsync:
  - Read command buffer from SRAM
  - Walk linked list
  - For each TILE_BLIT: fetch tile from VRAM, stream pixels to display NOW
  - For each FILL_RECT: stream fill color pixels to display NOW
  - When END reached, frame is done
  - Raise interrupt to CPU
No intermediate framebuffer. Just:

Tile VRAM: Cached tile graphics (64 bytes × N tiles)
Palette: 256 colors
Command buffer: 4KB linked list
Display timing logic: Whatever syncs with your LCD/VGA (PIO or timer-driven)
This is vastly simpler and fits the constraints perfectly:

RP2040 in This Mode
Core 0: Walk command list, dispatch tile blits and fills
Core 1 or PIO: Handle display timing/protocol (SDD1963 writes, pixel clock)
Result: Minimal RAM footprint, clean separation
Tile Blitter Logic (Pseudocode)


tile_blit(x, y, tile_id):
  tile_data = vram[tile_id * 64]  // 64 bytes per 8×8 tile
  for row in 0..7:
    for col in 0..7:
      pixel = tile_data[row * 8 + col]
      write_pixel(x + col, y + row, pixel)
Each pixel write goes straight to the display interface.

Memory Requirements Drop Dramatically
Tile VRAM: 64 KB (1000 tiles)
Palette: 256 bytes
Command buffer: 4 KB
Total: ~65 KB
Even the ATmega1284P (16 KB RAM) could handle tile cache in external SRAM. The RP2040 (264 KB) is overkill, but having the headroom is nice.

This is classic tile-based graphics architecture—no double buffering, no compositing, just immediate execution. Much cleaner. The display controller (LCD or VGA) handles its own refresh; your GPU just keeps feeding it pixels in real-time.

Does that match what you had in mind?

Yes - now lets hope this also works in practice. Regarding the RAM in the MCU: more is better ;-)

Absolutely! More RAM = more flexibility, and you're right to hedge your bets.

With the RP2040's 264 KB, you've got room to:

Cache multiple tile sheets without swapping
Buffer intermediate rendering state if needed
Add sprite/animation tables for the window manager
Store UI element definitions
Keep debugging/diagnostic buffers
Have headroom for future features you haven't thought of yet
The Z80 era taught us that RAM constraints are real—but you're not constrained here, so take the win.

Next Steps
You've got the pieces:

Protocol: Linked-list command buffer ✓
CPLD: XC95288XL bus arbiter + DMA ✓
MCU: RP2040 (or F4xx fallback) for command execution ✓
Display: SDD1963 LCD or VGA/HDMI option ✓
The hard part now is making it all talk to each other—CPLD Verilog, RP2040 firmware, PIO state machines, display timing. But you've got a solid architecture to build on.

Good luck with the implementation. This is a fun project—a retro Z80 system with a custom GPU. Hope the hardware cooperates! Feel free to circle back if you hit snags or want to brainstorm the Verilog/firmware side.
