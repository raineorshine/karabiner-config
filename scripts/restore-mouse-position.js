// Save the current mouse position, wait for the caller's synthetic click to finish, then put the
// cursor back where it was. Karabiner can move the cursor but cannot read it, so both the save and
// the restore have to happen here. The caller launches this first and then pauses long enough for
// the read below to run before it moves the cursor.

;(() => {
  ObjC.import('Foundation')
  ObjC.import('CoreGraphics')

  // Long enough to cover the caller's cursor move, click, and keystroke.
  const RESTORE_DELAY_SECONDS = 0.5

  const position = $.CGEventGetLocation($.CGEventCreate($()))

  $.NSThread.sleepForTimeInterval(RESTORE_DELAY_SECONDS)
  $.CGWarpMouseCursorPosition($.CGPointMake(position.x, position.y))
})()
