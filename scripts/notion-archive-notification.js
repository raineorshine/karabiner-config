// Move the pointer to a screen position, click it, and put the cursor back.
//
// Unlike Karabiner's set_mouse_cursor_position, which warps the cursor without posting a
// mouse-moved event, this walks the pointer there in steps with real CGEvents. Chromium updates its
// hover target from those events, so a hover-revealed button is actually under the pointer when the
// click lands, instead of the click hit-testing against whatever Chromium last believed was there.
//
// Posting CGEvents requires Accessibility permission. Karabiner holds it and the processes it
// spawns inherit it, so this works when Karabiner runs it. Run the same command from a terminal and
// the events are silently filtered and the pointer never moves, which makes it look like a no-op.
//
// Usage: osascript -l JavaScript notion-archive-notification.js <x> <y>

function run(argv) {
  ObjC.import('Foundation')
  ObjC.import('CoreGraphics')

  const targetX = parseFloat(argv[0])
  const targetY = parseFloat(argv[1])

  // Chromium does not need the motion to look human, only to arrive as events it processes, which is
  // the one thing a cursor warp never provides. A few steps are enough; ten was imitating a hand.
  const STEPS = 3
  const STEP_INTERVAL_SECONDS = 0.004

  // The only wait that does real work: the row hover has to render the archive button before the
  // click can land on it. Raise this first if a press ever fails to archive.
  const SETTLE_SECONDS = 0.05

  const CLICK_SECONDS = 0.012

  // Just enough that the click is delivered before the cursor leaves. The mouse up has already been
  // posted by this point, so this is a small margin rather than a requirement.
  const AFTER_CLICK_SECONDS = 0.02

  const sleep = seconds => $.NSThread.sleepForTimeInterval(seconds)
  const at = () => $.CGEventGetLocation($.CGEventCreate($()))

  /** Post a mouse event with the modifier flags cleared, so a held Cmd+Shift does not turn a click into Shift+Click. */
  const post = (type, x, y) => {
    const event = $.CGEventCreateMouseEvent($(), type, $.CGPointMake(x, y), 0)
    $.CGEventSetFlags(event, 0)
    $.CGEventPost(0, event)
  }

  const MOUSE_MOVED = 5
  const LEFT_DOWN = 1
  const LEFT_UP = 2

  const start = at()

  // Walk to the target so Chromium sees motion, not a teleport.
  for (let step = 1; step <= STEPS; step++) {
    post(MOUSE_MOVED, start.x + ((targetX - start.x) * step) / STEPS, start.y + ((targetY - start.y) * step) / STEPS)
    sleep(STEP_INTERVAL_SECONDS)
  }

  sleep(SETTLE_SECONDS)
  const arrived = at()

  post(LEFT_DOWN, targetX, targetY)
  sleep(CLICK_SECONDS)
  post(LEFT_UP, targetX, targetY)
  sleep(AFTER_CLICK_SECONDS)

  $.CGWarpMouseCursorPosition($.CGPointMake(start.x, start.y))
}
