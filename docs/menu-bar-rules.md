# Menu bar rules (drive the app's own menus)

When an app refuses to give a command up — it binds the chord internally and ignores a native macOS
App Shortcut override — and the menu item's own accelerator collides with something global, the way
in is the app's own menu.

**One `osascript` line says whether this route exists at all.** `tell application "System Events" to
tell process "<app>" to get name of every menu item of menu 1 of menu bar item "View" of menu bar 1`.
Karabiner-Elements' own settings answers `Enter Full Screen` and nothing else — no menu names its
sidebar sections, so the rule went through accessibility instead
([accessibility-rules.md](accessibility-rules.md)).

**The sequence.** `fn+Ctrl+F2` focuses the menu bar, a letter type-selects the menu title, **Down
opens it**, more letters type-select the item, and Enter activates it. The Down is not optional:
type-select only *highlights* a menu title, so without it the item letters keep type-selecting along
the menu bar row and Enter fires on whichever title is highlighted by then. Emit `f2` with
`"modifiers": ["fn", "control"]`, or the `fn_function_keys` translation turns it into a brightness key
([system-shortcut-rules.md](system-shortcut-rules.md)).

**Convert the typed letters.** They are ordinary type-select input and go through the macOS Colemak
input source, so convert each one to the physical key that types it, exactly as for palette text.

**These sequences need no pauses at all.** Menu tracking runs a modal event loop that consumes the
event queue in order, so each event waits for the stage before it instead of racing it. The
Cmd+Shift+1/2 sidebar-tab rule shipped with 150/150/150/120ms; the same sequence at 0ms passed 20 of 20
presses. Those presses were unloaded: if a menu rule ever misfires, suspect a busy renderer delaying
the menu, and measure before adding a constant back ([pauses.md](pauses.md)).
