// Move the pointer to a screen position and click it, then put the cursor back.
//
// Karabiner's own set_mouse_cursor_position *warps* the cursor: it moves without posting a mouse
// event. Chromium and Electron apps track their hover target from events, not from where the cursor
// actually is, so a click after a warp hit-tests against whatever the app last believed was under
// the pointer. For a button that only exists while its row is hovered that is the element
// underneath, and the click activates the wrong thing while the button sits there looking hovered.
// This walks the pointer over with real CGEvents, which the app processes normally, so its hover
// target is correct by the time the click lands. No dwell tuning can substitute for that.
//
// Posting CGEvents requires Accessibility permission. Karabiner holds it and the processes it
// spawns inherit it, so this works when Karabiner runs it. Running the same command from a terminal
// silently filters the events and the pointer never moves, which looks like the script is broken.
//
// Usage: osascript -l JavaScript mouse-click.js <x> <y> [--no-click] [--no-restore]
//
//   --no-click     move the pointer to the position but do not click
//   --no-restore   leave the cursor at the position instead of putting it back
//
// Coordinates are absolute points on the main display, so a caller only lands correctly while its
// target window is in its usual position and size.

function run(argv) {
  ObjC.import('Foundation')
  ObjC.import('CoreGraphics')

  const flags = argv.filter(argument => argument.startsWith('--'))
  const [targetX, targetY] = argv.filter(argument => !argument.startsWith('--')).map(parseFloat)
  const shouldClick = !flags.includes('--no-click')
  const shouldRestore = !flags.includes('--no-restore')

  // The app does not need the motion to look human, only to arrive as events it processes, which is
  // the one thing a warp never provides. A few steps are enough.
  const STEPS = 3
  const STEP_INTERVAL_SECONDS = 0.004

  // The only wait that does real work: a hover-revealed button has to render before the click can
  // land on it. Raise this first if a caller ever clicks through to whatever is underneath.
  const SETTLE_SECONDS = 0.05

  const CLICK_SECONDS = 0.012

  // Just enough that the click is delivered before the cursor leaves. The mouse up has already been
  // posted by this point, so this is a margin rather than a requirement.
  const AFTER_CLICK_SECONDS = 0.02

  const MOUSE_MOVED = 5
  const LEFT_DOWN = 1
  const LEFT_UP = 2

  const sleep = seconds => $.NSThread.sleepForTimeInterval(seconds)

  /** Post a mouse event with the modifier flags cleared, so a modifier still held from the shortcut that triggered this does not turn the click into e.g. Shift+Click, which extends a text selection instead of pressing the button. */
  const post = (type, x, y) => {
    const event = $.CGEventCreateMouseEvent($(), type, $.CGPointMake(x, y), 0)
    $.CGEventSetFlags(event, 0)
    $.CGEventPost(0, event)
  }

  const start = $.CGEventGetLocation($.CGEventCreate($()))

  for (let step = 1; step <= STEPS; step++) {
    post(MOUSE_MOVED, start.x + ((targetX - start.x) * step) / STEPS, start.y + ((targetY - start.y) * step) / STEPS)
    sleep(STEP_INTERVAL_SECONDS)
  }

  if (shouldClick) {
    sleep(SETTLE_SECONDS)
    post(LEFT_DOWN, targetX, targetY)
    sleep(CLICK_SECONDS)
    post(LEFT_UP, targetX, targetY)
    sleep(AFTER_CLICK_SECONDS)
  }

  if (shouldRestore) {
    $.CGWarpMouseCursorPosition($.CGPointMake(start.x, start.y))
  }
}
