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
