// Save the current mouse position, wait for the caller's synthetic click to finish, then put the
// cursor back where it was. Karabiner can move the cursor but cannot read it, so both the save and
// the restore have to happen here. The caller launches this first and then pauses long enough for
// the read below to run before it moves the cursor.
//
// Usage: osascript -l JavaScript restore-mouse-position.js [delaySeconds]
//
// The delay has to outlast everything the caller does after moving the cursor, so a rule with more
// steps than a move and a click has to pass its own.

function run(argv) {
  ObjC.import('Foundation')
  ObjC.import('CoreGraphics')

  // Long enough to cover the caller's cursor move, click, and keystroke.
  const DEFAULT_DELAY_SECONDS = 0.5

  const delaySeconds = argv.length > 0 ? parseFloat(argv[0]) : DEFAULT_DELAY_SECONDS
  const position = $.CGEventGetLocation($.CGEventCreate($()))

  $.NSThread.sleepForTimeInterval(delaySeconds)
  $.CGWarpMouseCursorPosition($.CGPointMake(position.x, position.y))
}
