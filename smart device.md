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
  - Handshake/interfaces with MCU for reading/writing the buffer RAM
- SRAM
  - (multiple) buffers exchange buffers
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
