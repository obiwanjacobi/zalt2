# Smart Device

## DMA Data Exchange

For an efficient data transfer between an user application and a smart device, DMA will be used.
With a short interruption of the CPU -the application won't notice- large amounts of data can be moved as fast as the RAM chips will go (typically using the CPU clock).

A general solutions could look like:

- CPLD
  - handles the mechanics of interfacing with the CPU
    - device-int + bus-req
    - reading/writing memory (A0-A15 + D0-D7 + CPU-Ctrl)
  - manages/connects local buffer RAM
    - on-device storage where data is staged for interaction with MCU
    - mux between DMA runs and MCU access
    - manages dual access to single RAM chip (DMA has prio)
  - Handshake/interfaces with MCU for reading/writing the buffer RAM
- SRAM
  - (multiple) exchange buffers
  - MCU stages data to be sent to CPU/application memory
  - CPLD dumps data that was read from CPU/application memory
- MCU
  - Implements the device services (FileSystem/Graphics Acceleration/etc)
  - Interfaces with device specific IO (Data Storage/VGA|HDMI/etc)

| Component | Pins | Description |
| -- | -- | -- |
| CPLD | 25 | Buffer/fast SRAM 32k (A:14+D:8+Ctrl:3) |
| | 29 | CPU bus / DMA (A:15+D:8+Ctrl:3+Int:3) |
| | 12 | Handshake interface MCU (D:8+Ctrl:4) |
| | 1 | Additional CPU-IO pin for accessing registers |
| SRAM | 25 | 32kB (A:14+D:8+Ctrl:3) - connected to CPLD |
| MCU | 12 | CPLD handshake (D:8+Ctrl:4) - connected to CPLD |
| | n | Additional pins for interfacing |

This setup allows the MCU to perform work asynchronsouly and stage its data in the buffer RAM (for reading),
or take its time while retrieving data from the buffer RAM when writing.
The buffer RAM is large enough to contain at least 2 times the size of the shared memory.
When a new DMA transfer needs to take place while the MCU is still busy, it can halt the MCU interaction to do an DMA burst.

## Shared Memory

See also [External DMA](./Main%20Board%20v2.0/Source/CPLD/readme.md#external_dma)

An application and a smart device share a 4k memory page (or more than one) for data exchange.
The application sets this up and tells the device (via os-driver) where to find it.

Each device gets its own memory bank that is used to map in the shared memory page(s) at a predetermined location (device specific).

## Protocol

The protocol for data exchange between an application and a smart device is based in memory.
Dependent on the type of smart device, different variations/combinations might be needed, but here is the general idea:

The application sets up a memory area in a 4k memory page for data exchange with a specific device.
Potentially each smart device gets its own memory page.
There are tree types of memory area that may be required for the device:

- Commands: contains one or more command structures that instruct the device what to perform.
- Data: filled by the application (for write) or the device (read) as command input (parameter) or output (result).
- Event: A small area where the device will put the next (or all?) available event. A device-interrupt may signal the presence of one or more events.

After the application has finished preparing the command and possible data, it calls a specific IO port on the device (via os-driver) to let it know what action to perform: 'command' or 'command + data' for example.

The device requests the CPU-bus through raising an interrupt with a bus-request signal.
The CPLD manages handling the interrupt and requesting the CPU bus. It also changes the active MMU configuration to the one specific for that device (based on the interrupt prio).

The device performs the DMA transfer as soon as it receives an acknowledge from the CPLD.
If there is incomming data for the command that is copied also.
After the command(s) (and data) are copied into the device's own memory, it releases the CPU bus.

Now the device will work on performing the command while the CPU is free to do other things.
When the device-operation is ready, it can raise an interrupt to let the application know.
Additionally it could have prepared one or more events to be sent out (retrieved by the application).
The application can retrieve the event(s) with a call to the same operation IO port that started the device-operation, but with a different value: 'events' for example.

The commands themselves can contain information/flags for what type of signaling is requested.

For some devices it may be required to be able to have many commands in one exchange, think of a video device that gets an entire new screen definition to redraw.

In that case the command memory area is managed like an object pool of linked-list items.
Each command has a pointer/offset to the next command, always starting at the root-header.
When changes need to occur, the application can add, insert, replace or remove commands simply by manipulating the pointers/offsets.

Additional data, like strings, referenced by the commands are stored in the same memory page (accessible by the device).

When a command item is disposed it is marked as free and can be reused for further 'allocation'.
Any referenced (dynamic) data is also freed. This is basically a mini-heap.

> TBD: if the heap for dynamic data will also be an object heap with fixed-size items. Otherwise fragmentation could get nasty when commands and their accompanied data are freed.

### Command Structure

```c
// first in command memory (entry point)
struct CommandHeader {
  rel_ptr_t FirstCommand;
  // other fields?
  void* FreeList;   // managed off-site/different page?
};
```

```c
// generic base for every command to allow traversal
struct Command {
  rel_ptr_t NextCommand;
  uint8_t CommandType;      // is 255 command type enough?
  uint8_t Length;           // not strictly needed
};
```

```c
// specialized device command
struct DeviceCommand {
  Command command;          // always start with command base
  // device command specific fields
};
```

### Event Structure

```c
// generic base for events
struct Event {
  uint8_t EventId;
};
```

```c
// specialized device event
struct DeviceEvent {
  Event event;              // always start with event base
  // device event specific fields
};
```
