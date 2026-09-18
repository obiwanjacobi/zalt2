# Zalt OS

Notes on a Zalt os.

## Multi-Tasking

The hardwarde (MMU) can handle multiple tasks. So it stands to reason to have the OS load more than one application that can run (at a time).

The system-timer will be the clock that the task-scheduler will use to activate the different tasks (round robbin) - preemptively. Inside a task, there is no threading (one main 'thread'). A cooperative (Async) mechanism is to be used. You can only starve your own sub-tasks if you take too long.

The OS takes up (at least) one Task (with the highest prio) that is ran outside of the standard scheduling algorithm (assume round robin). At each system-timer tick when the task-scheduler interrupt handler runs, it checks with the OS task to see if work needs to be done (typically hardware signaled), if so it is given priority.

Data per Task:

- Register Data (SP+PC) (Context Switch)*
- Memory Pages Allocated / Current Bank
- Entry Point
- Interrupt handlers? Soft-handlers that are called by the OS (when Task is scheduled).

*) instead of keeping track of all registers for all tasks at a central place (the scheduler), each task could store their own state  (on stack if needed) and we only have to keep track of the current SP for that task. When it is reactivated, we pop all registers off the stack in reverse order and continue.

Task API:

- `Task_Yield` / `Task_Sleep`
- Locking Shared Resources? Lock/Mutex
- Inter Process (Task) Communication? Pipes, Shared Memory (Mapped File)?
- Atomic operations -prevent task switch for a short time.

> We can reserve `HALT` as a yield+idle and wait for next scheduling interrupt. Although it would not be used often? If a task yields and we do not have to perform other (OS) tasks...

### Task Isolation / OS Protection

Task are isolated from each other (as much as possible):

- Have their own MMU Bank Map - no application memory is shared between tasks (except library code).
- Have their MMU Pages marked with Writable and Executable bits.
- The OS preemtively schedules Task execution. It is not possible for a Task to hijack the CPU.

The OS protects its code from illegal access by:

- Marking its MMU Pages with the OS bit. The CPLD monitors execution to manage a supervisor bit and will invalidate the memory access (write/execute) when illegal (MMU page has OS bit on but the supervisor FF is off).
- OS functions (RSTs tracked by the CPLD) can switch to their private stack and MMU banks to pull-in additional data/code.
- The CPLD can even track `IORQ` (+ address) to prevent illegal IO-requests (supervisor bit).
- The CPLD only allows MMU IO-access when supervisor bit is on.

## Program Loader

The program loader reads in a binary file and loads it into the correct memory pages.
The ultimate idea is for a program to be fully relocatable and to have segments defined that will be loaded into the memory pages (MMU). Ideal would be that each segment would also be relocatable so it can be reordered in the CPU address space. But that is probably too complex to manage and write (as a programmer of the application).

It would require an application programmer to output the program in 4k sections.
These sections have to carfully chosen to minimize the need to switch memory pages/sections in and out when calls are made across sections.
The problem of where (what memory page) the called function lives and if it is mapped into CPU address space are a burdon of the os and unclear (at this time) if it can be done. A jump/dispatch table for a program (or each section?) would make it easier to keep track of that.
Note that each Task/Process has its own set of MMU banks and therefor application/task specific bookkeeping is pretty easy.

## Memory Allocation

Memory allocations can be global (heap) - in a memory page shared (and fixed?) by all applications. Limited resource.
Memory Allocation can be local (heap) - in a memory page that is reserved for the application that made the allocation/reservation.

> I would prefer not to have a generic 'malloc' but specific allocators for each specific scenario in an attempt to optimize it as much as possible.

Memory Allocators:

- Arena: Manages a big(ger) block of memory to satify smaller allocations. Typically freed after call tree returns.
- Pooled: Manages a pool of same sized allocation, typically pre-allocated and (optional) pre-initialized.
- Stack: Manages allocations in a FIFO way. Freeing a ptr also free all ptrs that were allocated later.

Normal Stack allocation (local vars) is done through the programming language.

> Can memory be reseverd? And is this then guaranteed?

Dedicated memory pages can be allocated (per task) for smart-device interaction.
These pages are mapped to both the specific device and the application in order for them to share data.

A similar mechanism could be constructed to share data between applications.

## OS Devices

- Physical Devices: Console, Storage, Keyboard?, Mouse?, Video?, Audio?
  - Character Devices: Exchange one byte at a time.
  - Block Devices: Exchange blocks of data at a time.
- Logical Devices: Point to physical devices - can be reassigned at runtime.
  - Null Device: does nothing - data writen is ignored, read is EOF.
  - StreamTap Device: duplicates an out-Stream to an additional device (copy). What to do with read?
  - CharAdapt Device: adapts a block device to be a character device.

Character Devices:

- Console (in/out)
- Keyboard
- Mouse
- Serial

Block Devices:

- Storage (read/write)
- Printer
- Audio
- Video

Each Device Driver implements at least the Stream-Provider API.

| API | Description |
| -- | -- |
|`TryStreamOpen` (async)| Establishes a connection with the stream source (hardware or file). May allocate memory. |
|`TryStreamClose` (async)| Disconnects from stream source and cleanup (free memory). |
|`TryStreamRead` (async)| Reads a block from the underlying device/file. |
|`TryStreamWrite` (async)| Writes a block to the underlying device/file. |

Block devices manage the size of the block and the memeroy required for block data exchange.

### Everything is File (Stream)

> TBD: this is an old concept that may not be the best fit.
It has issues in its (leaky) abstraction and should be async.

Asynchronous Stream-based API interfacing with files and devices.

Content or Data Stream contains the actual data.
The format of the data is dictated by the type of underlying file or device that was opened.

A Meta Stream reports the metadata on the stream and its contents. Examples are:

- file name and attributes
- video mode/resolution

A Stream is opened using an 'uri' that identifies the device (StreamProvider) and the stream source (or target).
The 'uri' is very condensed and simplified to make parsing easy. The way device data is identified (files for instance) is device-dependent. A 8.3 file system (FAT16) will required 8.3 identifiers.

- `con:def` / `con:dbg` default or debug console
- `file:mynotes.txt` targets a file called mynotes.txt
- `file:folder/dir/notes.txt` a file nested in folders.
- `dev:con` information on the device itself.

Basic Stream API.

| API | Description |
| -- | -- |
|`Stream_Construct`| initializes a new stream struct.|
|`Stream_Open`(async)| opens the stream by 'uri'.|
|`Stream_Close` (async)| closes the stream (struct).|
|`Stream_Read` (async)| reads from the stream (char and/or block?)|
|`Stream_Write` (async)| writes to the stream (char and/or block?)|
|`Stream_Seek` (async)| skips through the contents of the stream. Not all devices may support it.|
|`Stream_CanRead`| Indicates if there is something to read from the stream.|
|`Stream_CanWrite`| Indicates if there is room to write to the stream.|

Stream API extensions.

For some devices the basic Stream API is not sufficient.
Additional APIs can be provided by the device (driver) to unlock the extra functionality.
Additional APIs can also aid in reading/writing a specific data format into/from the content or meta streams.

Examples of devices that require extra APIs

- Storage
- Audio
- Video

## Memory Map

- 512kB ROM
- 512kB RAM

- Memory Page is 4kB
- Number of active Pages: 16 (16 x 4kB = 64kB)
- Memory Bank is 64kB (16 Pages) - layout of memory in Z80 address space.
- Total number of addressable Pages: 8192 (32MB)

A Memory Page can be positioned in any 4kB slot in the Z80 address space.

### Z80 CPU Address Space

There are 16 pages of 4kB in CPU memory.

| Idx | Start | End | Size | Description |
| -- | -- | -- | -- | -- |
| f | $F000 | $FFFF | 4kB | |
| e | $E000 | $EFFF | 4kB | |
| d | $D000 | $DFFF | 4kB | |
| c | $C000 | $CFFF | 4kB | |
| b | $B000 | $BFFF | 4kB | |
| a | $A000 | $AFFF | 4kB | |
| 9 | $9000 | $9FFF | 4kB | |
| 8 | $8000 | $8FFF | 4kB | |
| 7 | $7000 | $7FFF | 4kB | |
| 6 | $6000 | $6FFF | 4kB | |
| 5 | $5000 | $5FFF | 4kB | |
| 4 | $4000 | $4FFF | 4kB | |
| 3 | $3000 | $3FFF | 4kB | OS-resident |
| 2 | $2000 | $2FFF | 4kB | OS-resident |
| 1 | $1000 | $1FFF | 4kB | OS-resident |
| 0 | $0000 | $0FFF | 4kB | OS-resident |

The number of 'OS-resident' pages is not yet determined.

## Tasks and Banks

- Number of Tasks: 64 (6-bits)
- Number of Banks (per Task): 32 (5-bits)

Total of 11 bits.

The CPLD manages the MMU Tasks/Banks.

| Task | Bank | Description |
| -- | -- | -- |
| 0 | 0 | Fixed OS Bank that manages os-function dispatching. |
| 0 | 1-23 | OS and device-driver functional memory configurations. |
| 0 | 24-31 | Last 8 Banks are reserved for Smart Device / Extension Bus IO transfer memory configuration. |
| 1-63 | 0-31 | Custom Task (program) memory layout configured by the ProgramLoader. |

MMU-Banks can be used as a stack, where each new memory layout is another bank.
When the code is done with that layout it can be popped and the previous layout is reactivated.

### OS Memory

| Page | Description |
| -- | -- |
| 0-n | OS entry point and book keeping. All Banks have these Pages mapped at the beginning of the CPU address space. |

These first pages contain the data variables required by the OS, OS-function entries (function tables) and interrupt handlers.

| Type | Description |
| -- | -- |
| OS Resident Code | OS code that needs to be accessible at all times (mapped into all Banks) |
| OS Resident Data | OS data that needs to be accessible at all times (mapped into all Banks) |
| OS Code/Data Segments | OS function-specific code segments that are mapped in/out whenever needed, such as device-driver code. Can be mixed with data variables (only OS can do that). |
| OS Blob | Static data used by the OS. Logos, fonts, math tables etc. Located in ROM. |

Some of the OS code may be located in ROM.
Some other code may be loaded from the MCU system SD-Card into RAM.

The OS is 'loaded' and initialized during the boot-sequence when the system starts.

### Application Memory

Typically the following types of segements are in play for a typical application:

| Type | Description |
| -- | -- |
| Application Code | There can be multiple segements of application code |
| Application Data | Initialized, uninitialized variables and the call stack |
| Application Blob | Large binary objects (files, images etc) that are read (or written) in chunks (4-8kB) - windowed data access. |
| Shared Code | Shared library code that can be used by multiple applications (stateless) |
| Dispatch | Jump table where the application jumps to another Bank to access additional code. This segement is always present in all Banks for the application (Task) |

> It would be nice if the OS could perform an application call stack check to prevent or at least detect a stack overrun, where either the stack overwrites application data or visa versa.

Although the memory page size is 4kB, these segments may span multiple pages.
The maximum number of pages that is in CPU address space at one time for an application (incl. dispatch) is dependent on the number of memory pages required by the resident part of the OS.

The application is loaded and initialized by the OS Program Loader that will place the code and data in memory (pages) and configure the Banks to represent the required segements.
