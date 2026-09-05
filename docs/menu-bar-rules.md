# Menu bar rules

## Menu bar rules (drive the app's own menus)

**One `osascript` line says whether this route exists at all.** `tell application "System Events" to
tell process "<app>" to get name of every menu item of menu 1 of menu bar item "View" of menu bar 1`.
Karabiner-Elements' own settings answers `Enter Full Screen` and nothing else — no menu names its
sidebar sections, so there was nothing to type-select and the rule went through accessibility
instead.

When an app refuses to give a command up — it binds the chord internally and ignores a native macOS
App Shortcut override — and the menu item's own accelerator collides with something global, the way
in is the app's own menu. `fn+Ctrl+F2` focuses the menu bar, a letter type-selects the menu title,
**Down opens it**, more letters type-select the item, and Enter activates it. The Down is not
optional: type-select only *highlights* a menu title, so without it the item letters keep
type-selecting along the menu bar row and Enter fires on whichever title is highlighted by then.

The typed letters are ordinary type-select input and go through the macOS Colemak input source, so
convert each one to the physical key that types it, exactly as for palette text.

**These sequences need no pauses at all, and that is a property of menus rather than luck.** Menu
tracking runs a modal event loop that consumes the event queue in order, so each event waits for the
stage before it instead of racing it. The Cmd+Shift+1/2 sidebar-tab rule shipped first with
150/150/150/120ms; a probe of the same sequence at 0ms then passed 20 of 20 presses, so those
constants were covering nothing. The floor here is zero, not merely small, and a margin over a floor
of zero would be paying latency on every press to cover a race that was shown not to exist.

The distinction worth holding onto is not menus versus clicks, though — both floors turned out to be
zero. It is whether anything is actually racing. A queued key event waits its turn by construction.
A click races only when the thing it lands on is not there yet: a hover-revealed button, or a popup
still drawing. A click at a target that is already on screen races nothing either, which is why
Cmd+P's warp-to-click gap went to 0 as cleanly as this menu sequence did. Before reaching for
`hold_down_milliseconds`, name the transition you are waiting on. If you cannot name one, there
probably is not one.

(The 20 presses were unloaded. If a menu rule ever misfires, suspect a busy renderer delaying the
menu, and measure before adding a constant back.)
