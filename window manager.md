# Window Manager

(Analog to a tiling window manager)

See also [video display](<./video display.md>)

To keep a GUI simple, responsive and light-weight:

One bar at the top of the screen (like an old Mac) containing the (focused) application's main menu and some simplified Taskbar functionality.

The rest of the screen is to display the main window of the current application.
More than one application can be active.

There is a stack of 'main screens' that can be active - one at a time.
A layout definition for the stack slot defines what windows are displayed, where.

The simplest is simply one main window, that fills the screen. Another could have two smaller windows to the side, or add an additional small window at the bottom.

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

> It could be a good idea to implement the window manager inside the display interface card (smart device) and communicate with it using a higher-level protocol (no mult- monitor).

> Base the graphic representation on tiles and sprites (cursor) that can be (re)used for writing games?

> TBD:

- Can an application present more than one window that the system will treat as valid content for the screen layout? Even if that window is paired with one or more windows of other applications?

- Focus on hover? Could be a setting that the user can turn on/off.

> The RayLib graphics layout program can output .rlg files that contain control types and coordinates. Could be an easy way to design windows gui.

- Have a single line of console entry on the bottom of the screen? Enter a command line quickly. If large output needs to be read (by the user) it can be folded open/extended (upward).

- Have a Taskbar that gives quick access to all open applications.

- Have a default windows that serves like a start-menu, but full screen. All 'installed' applications are listed here.

## Menu Bar

There is one global top menu bar that displays the menu of the active application and starts at the left side of the screen.
When more than one application is shown on the same screen, the active application is the one that has the focus.

The application menu bar can be:

- Text: Sub-menus are text with optional small icon graphics and optional shortcut keys.
- A simplified ribbon type: a combination of a menu and a toolbar. More advanced.
- Something else? Text main menu's the fold-out onto toolbars?

On the right of the Menu Bar there is a system-provided way to manage Windows:

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

The application can use categories to group commands into a hierarchy. If a command-id is zero, its registration represents a category and the category-id must be set. The system will pre-define several common categories.

## Screen Controls

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

## Dialogs

An application can use system calls to open predefined Dialogs:

- Output Message
- Input Message
- Load File
- Save File
- Fonts*
- Color Picker*

*) Nice to Have

The dialogs are presented in the middle of the screen and are all Modal -you have to dismis the dialog before control is returned to the application.
