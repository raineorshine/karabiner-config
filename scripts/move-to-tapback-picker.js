// Move the pointer onto the emoji picker button of the Messages right-click menu the caller has just
// opened. The caller does both clicks; this only does the part Karabiner cannot, since
// set_mouse_cursor_position is absolute and the picker's position depends on where the menu landed.
//
// Why the menu rather than the tapback bar: Messages offers no keyboard route to the picker, and the
// hover tapback bar cannot be reached by a fixed coordinate, since it is anchored to the message
// bubble and so moves with the message's width and height. The right-click menu is anchored to the
// click point instead, and it is a window of its own, which means its frame can simply be read
// rather than predicted.
//
// Reading the frame is what earns this script its keep. The menu is not a fixed offset from the
// click: macOS shifts it up when it will not fit below, which is always the case for the last
// message in a conversation, and its height changes with the items the message happens to have, so a
// message carrying a link pins higher than a plain one. The picker sits at a constant offset inside
// the menu regardless, so anchoring to the frame sidesteps both. The offsets were measured on a 2x
// display: the picker's centre is 266.5 points right of the menu's left edge and 61.75 points below
// its top, in a menu measuring 302x263. The button is about 15 points across, so there is roughly 7
// points of slack.
//
// The menu takes a variable amount of time to appear, so this polls for it rather than assuming it
// is up: the caller's fixed wait would otherwise be a race, and a wait long enough to always win
// would make the shortcut sluggish. If the menu never appears the pointer is left alone, so the
// caller's click lands back on the message it right-clicked rather than somewhere unpredictable.
//
// This warps the pointer instead of posting mouse events. Warping needs no permission, while posting
// CGEvents needs Accessibility, and the events this script posts are silently filtered even though
// the ones mouse-click.js posts are not. Reading the window list needs no permission either; without
// Screen Recording it omits window titles, but the bounds and owner this relies on still come back.
//
// Usage: osascript -l JavaScript move-to-tapback-picker.js

function run(argv) {
  ObjC.import('Foundation')
  ObjC.import('CoreGraphics')

  // Offsets from the menu's top-left corner to the centre of the picker button.
  const PICKER_DX = 266.5
  const PICKER_DY = 61.75

  // Context menus sit at this window level, which is what distinguishes the menu from the Messages
  // window underneath it.
  const MENU_WINDOW_LAYER = 101

  // The budget has to leave the caller room to wait out this script's startup, measured at 70-110ms,
  // and still click afterwards.
  const POLL_BUDGET_SECONDS = 0.25
  const POLL_INTERVAL_SECONDS = 0.01

  const menuFrame = () => {
    const info = ObjC.castRefToObject($.CGWindowListCopyWindowInfo(1, 0))
    for (let i = 0; i < info.count; i++) {
      const window = ObjC.deepUnwrap(info.objectAtIndex(i))
      if (window.kCGWindowOwnerName === 'Messages' && window.kCGWindowLayer === MENU_WINDOW_LAYER) {
        return window.kCGWindowBounds
      }
    }
    return null
  }

  const deadline = $.NSDate.date.timeIntervalSince1970 + POLL_BUDGET_SECONDS
  let menu = menuFrame()
  while (!menu && $.NSDate.date.timeIntervalSince1970 < deadline) {
    $.NSThread.sleepForTimeInterval(POLL_INTERVAL_SECONDS)
    menu = menuFrame()
  }

  if (menu) $.CGWarpMouseCursorPosition($.CGPointMake(menu.X + PICKER_DX, menu.Y + PICKER_DY))
}
