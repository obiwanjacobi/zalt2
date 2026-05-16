# Zalt II

The design of the Zalt II computer hinges on a 10-slot (PC) ISA powered backplane I had laying around.

So all modules have an ISA edge connector and although the physical construction is the same as the (PC) ISA bus, the electrical connections are different. So don't try plugging the modules into an old PC.

All card modules (except the Main Board) represent a "smart device".
A smart device has it's own processor to give it additional functionality and perform DMA.

## Main Board v2.0 (manufactured)

The "motherboard" of the Zalt II computer, containing the 20MHz Z80 CPU, a CPLD for condensed system logic (like MMU/MPU) and an MCU for some (serial) peripherals.

## Mass Storage Card

> TBD

- Support IDE hard disks
- Support File System (FAT16/32)
- Efficient file data transfer (DMA and prefetch)

## Video Display Card

> TBD

Currently being researched.

We start of with a simple test on an (SSD1963) [LCD display](./Lcd%20display.md) I have.

- command-based interaction
- lots of graphic services (layers, sprites, transformations, animation, scrolling)
- Additional memory for storing graphic assets
- maybe even a built-in windowing system
- VGA and HDMI using a CPLD to do the heavy lifting
- MCU (STM32?) for 'accelerion', additional memory and DMA

## Audio Interface Card

> TBD

Fague ideas on what to do here.

- use MIDI (files) to drive the sound generator(s).
- use a teensy and the audio library (design) capabilities as the processor / sound generator.
- Allow samples to be uploaded and played.
- Prepare for recording audio samples (don't make it impossable), but no plans to use it.

## Network Card

> TBD

No idea yet how to do this, but seems like a good idea.

- LAN + WIFI (+BLE?)
- W5500 LAN module (AliExpress)
