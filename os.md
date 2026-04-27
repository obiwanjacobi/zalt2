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
- Inter Process (Task) Communication? Pipes, Shared Memory, Mapped File?
- Atomic operations -prevent task switch for a short time.

## Program Loader

The program loader reads in a binary file and loads it into the correct memory pages.
The ultimate idea is for a program to be fully relocatable and to have segments defined that will be loaded into the memory pages (MMU). Ideal would be that each segment would also be relocatable so it can be reordered in the CPU address space. But that is probably too complex to manage (as a programmer of the application) and write.

It would require an application programmer to output the program in 4k sections.
These sections have to carfully chosen to minimize the need to switch memory pages/sections in and out when calls are made across sections.
The problem of where (what memory page) the called function lives and if it is mapped into CPU address space are a burdon of the os and unclear (at this time) if it can be done. A jump/dispatch table for a program (or each section?) would make it easier to keep track of that.
Note that each Task/Process has its own set of MMU banks and therefor application/task specific bookkeeping is pretty easy.

## Memory Allocation

Memory allocations can be global (heap) - in a memory page shared (and fixed?) by all applications. Limited resource.
Memory Allocation can be local (heap) - in a memory page that is reserved for the application that made the allocation/reservation.

Memory Allocators:

- Arena: Manages a big(ger) block of memory to satify smaller allocations. Typically freed after call tree returns.
- Pooled: Manages a pool of same sized allocation, typically pre-allocated and (optional) pre-initialized.
- Stack: Manages allocations in a FIFO way. Freeing a ptr also free all ptrs that were allocated later.

Normal Stack allocation (local vars) is done through the programming language.

> Can memory be reseverd? And is this then guarenteed?

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

> Is there a Device hierarchy (parent-child)?

Each Device Driver implements at least the Stream-Provider API.

| API | Description |
| -- | -- |
|`TryStreeamOpen` (async)| Establishes a connection with the stream source (hardware or file). May allocate memory. |
|`TryStreamClose` (async)| Disconnects from stream source and cleanup (free memory). |
|`TryStreamRead` (async)| Reads a block from the underlying device/file. |
|`TryStreamWrite` (async)| Writes a block to the underlying device/file. |

Block devices manage the size of the block and the memeroy required for block data exchange.

### Everything is File (Stream)

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

## Smart Devices

Peripheral devices, like storage, video, audio etc. will be smart devices.
The idea is that communication is done at a higher abstraction level allowing the device to implement more services

Each device implements its own 'DMA' controller to effectively blast bytes over memory (in/out) in one or more memroy-page sized blocks.

## Window Manager

(Analog to a tiling window manager)

See also video display.md

To keep a GUI simple, responsive and light-weight:

One bar at the top of the screen (like an old Mac) containing the (focused) application's main menu and some simplified Taskbar functionality.

The rest of the screen is to display the main window of the current application.
More than one application can be active.

There is a stack of 'main screens' that can be active - one at a time.
A layout definition for the stack slot defines what windows are displayed, where.

The simplest is simply one main window, that fills the screen. Another could have two smaller windows to the side, or add a small window at the bottom.

This way the complexity is kept at a minimum and the user can still switch between applications.

```txt
|-----------------------------------|
|File Edit View Help         Windows|
|-----------------------------------|
|                                   |
|                                   |
|    This is the main app window    |
|                                   |
|                                   |
|                                   |
|-----------------------------------|
```

```txt
|-----------------------------------|
|File Edit View Help         Windows|
|-----------------------------------|
|                     |             |
|                     |             |
|    This is an       |  Secondary  |
|    app window       | app window  |
|                     |             |
|                     |             |
|-----------------------------------|
```

> It could be a good idea to implement the window manager inside the display interface card (smart device) an communicate with it using a higher-level protocol (no dragging windows over to another monitor then).

> Base the graphic representation on tiles and sprites (cursor) that can be (re)used for writing games?

> TBD:

- Can an application present more than one window that the system will treat as valid content for the screen layout? Even if that window is paired with one or more windows of other applications?

- Focus on hover? Could be a setting that the user can turn on/off.

> The RayLib graphics layout program can output .rlg files that contain control types and coordinates. Could be an easy way to design windows gui.

### Menu Bar

There is one global top menu bar that displays the menu of the active application and starts at the left side of the screen.
When more than one application is show on the same screen, the active application is the one that has the focus.

The application menu bar can be:

- Text: Sub-menus are text with optional small icon graphics and optional shortcut keys.
- A simplified ribbon type: a combination of a menu and a toolbar. More advanced.

On the right of the Menu Bar there is a system-provided way to manage windows:

- Open an application:
  - into a new window
  - add to the current window
- Move an application
  - to a different pane in the current screen (like swap)
  - to a new screen
- Close an application
- Show a list of open Applications
- Order the stack of screens

> If we let the application register Commands (not menu UI) the system can present it any whay the user likes.
The way VScode works with commands in a central drop list at the top of the screen may be a very compact and general way to invoke application functionality. What would light-weight commands look like?

- Command Id (zero when category)
- Category Id (hierarchy of commands)
- Text (Title/Description)
- Icon-Reference (graphic) (optional)
- Shortcut Key Binding

The application registers commands at startup (or declarive in binary?). Command-state (enabled/disable) can be retrieved from the app through a standard interface.

The application can use categories to group commands into a hierarchy. If a command-id is zero it registration represents a category and the category-id must be set. The system will pre-define several common categories.

### Screen Controls

Besides menus, several other re-usable, system-provided screen controls are available:

- Push Button
- Switch/Toggle
- Radio Button (can be used to make tab-strip)
- Selection/List Box  (popup overlay)
- Text (formatted)
- Picture (Image)
- Drag Handle (sizing, splitter)
- Panel (control grouping + text)

Layout Controls:

- Grid Layout (column and row spanning)
- Stack Layout (horizontal/vertical)
- Well (Pile?) Layout (only one visible at a time)

### Dialogs

An application can use system calls to open predefined Dialogs:

- Output Message
- Input Message
- Load File
- Save File
- Fonts
- Color Picker

The dialogs are presented in the middle of the screen and are all Modal -you have to dismis the dialog before control is returned to the application.
