# Video Display

Some ideas on video display.

The Video Display is a smart device that goes beyond pushing pixels to a screen.
It implements several services that off-loads the application (or os) from having to (re)implement them.

Video Modes:

- Graphics mode: free graphics canvas. Ideal for games
- Windowing Mode: Simple Windowing system (also see os.md)
- Text mode: text based content area(s).

Video Memory:

- Double-buffered to mitigate VRAM contention.
  - How to prevent having to redraw everything by the application each time a new frame is prepared?
- Extra space for the application to upload artifacts that can be referenced in the screen.

Services:

- Functional Protocol
  - Higher-level functions for common graphic operations.
  - Off-load CPU/application
  - see earlier designs.
- Tile-based implementation with (software/hardware?) sprites.
  - Reduce the redraw time / only redraw what changed.
  - Tiles/sprites/images can be preloaded for additional performance
  - Works well for games
  - Can Windowing System be based on this?
- Text Scaling: Allow drawing text an various sizes.
- Simplified CSS-like styling. A simple way to style and color screen elements.
- Common GUI controls provided.

## Graphics System Implementation

- Immediate Mode drawing is where the entire screen is redrawn based on the new state of the graphics definition.
- Retained Mode drawing is where each graphics element is retained/kept around to make changes to.

The immediate mode produces simpler code for drawing the graphics elements as they should look 'now' and fits in nicely with double-buffered hardware where each frame has to be redrawn in the buffer that is not used for display.

Retained mode requires state management for each element between how the element did look and how it should look 'now'.

> We choose Immediate Mode

Data exchange with the application/CPU is done through a dedicated memory page (4k).
This memory is basically a ring-buffer that the application writes to and the video device reads from.
There might be a second (smaller) ringbuffer (in the same memory page?) for 'events' from the video device screen elements for the application to handle.

The need to be a signaling method of letting the other party know new data is available.
The fact that there is data in the ring-buffer is not sufficient because that data may be incomplete when it is just being written.

The Stream API will also need a signal when it's done. Reuse the Stream for reading and writing.

The Video device will request the CPU bus to read/write the ring-buffer data,
so no contention can ever take place on that data because the CPU is not running at that time.

### Window Manager

For the Window manager the application would exchange a list of commands that define the window and it's screen elements and content.

An hierarchical data structure is needed but that can be flattened by giving
containers and id and referencing those ids as parents in the child elements.

With any luck this list only has to be communicated once by the application and the Window Manager caches it for redraws and resizes.

Opening dialogs can be send separately by the application.

#### Layout

Graphics layout requires two passes: one measure pass that determins sizes and positions of elements and then a drawing pass (top down).

Explanation: Clay Layout: https://www.youtube.com/watch?v=by9lQvpvMIc

## UI Library Resources

Some ideas:

C-layout (Clay)
https://github.com/nicbarker/clay
https://www.youtube.com/watch?v=DYWTw19_8r4

micro-ui
https://github.com/rxi/microui

ui-slice
https://github.com/coolacpc/uislice

raylib (gaming)
https://www.raylib.com/index.html
