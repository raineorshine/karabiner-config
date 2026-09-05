# Click rules

## Click rules (move the mouse and click)

**Check the accessibility tree before writing a click rule at all.** A click rule is a coordinate
pair that holds only while the window is in its usual position and size, a cursor left somewhere it
was not, and — whenever the target is not already on screen — a race to tune. `ax-press` has none of
those: it names the control, costs 29-78ms, and reaches an element scrolled out of view. Shortwave's
Always apply toast was a coordinate warp-and-click until the tree was dumped, and the target turned
out to be an `AXButton` titled "Always apply". See [accessibility-rules.md](accessibility-rules.md). What follows is for targets
the tree does not name — an unlabelled control, a point on a canvas, an app that exposes nothing
useful. The rules that already click work; this governs new ones.

**Once you are clicking, default to Karabiner's own `set_mouse_cursor_position` +
`pointing_button`.** It stays inside Karabiner, so it is faster than spawning a process, and it is
fine for any target that is *already on screen*. Done this way a click rule needs no
`hold_down_milliseconds` at all: Cmd+P and Cmd+Shift+U are a bare warp, click, `vk_none` and fire
with no deliberate delay. Cmd+Shift+P and Cmd+Shift+G still carry the older spawn-and-hold shape
described below.

**A hover-revealed target may need real motion — observed in Notion, and only there.**
`set_mouse_cursor_position` *warps* the cursor without posting a mouse event. Notion's archive
button, which exists only while its row is hovered, painted as hovered while the click hit-tested
against the element underneath and activated that instead. Every workaround failed *there*: extra
warps, one-point nudges, two-stage hovers, `mouse_key` motion, double clicks, and dwell tuning in
either direction (130ms worked, 250ms was flaky, 400ms failed outright). Only real motion fixed it.

The explanation usually given — that Chromium/Electron track the hover target from events rather
than from where the cursor is — is a hypothesis fitted to that one rule in that one app. It has not
been checked anywhere else, so it is not a reason to expect the same of any other hover-revealed
button, in Electron or otherwise. Warp and click first; reach for the script when warp-and-click has
actually been seen to fail on the target in front of you. And note the corner this leaves: if an app
does need posted motion *and* posting is filtered there (below), there is no route at all —
recognise that as a dead end rather than tuning at it.

`scripts/mouse-click.js <x> <y> [--no-click] [--no-restore]` walks the pointer there with real
`CGEvent`s, clicks with the modifier flags cleared, and restores the cursor. The Notion archive rule
uses it. Measured: `osascript` is 66ms to start, 77ms with the ObjC imports, 100ms by the time it
has read the cursor (p50, 400 samples), and ~195ms from spawn to the click landing once its motion
and 50ms settle are added. That is why it is not the default — and why it cannot rescue a slow rule,
since the spawn dominates whatever pauses you trim.

**Diagnosing which case you are in:** click something always-visible nearby with a plain warp and
click. If that works and your target does not, the difference is the target, not the mechanism —
which narrows it, but does not tell you the script is the fix. That was only ever established for
Notion's hover-revealed archive button. Confirm posting works at all (below) before assuming the
script is available as a remedy.

**Whether a spawned script may post `CGEvent`s is unpredictable — probe it every time.** Posting
needs Accessibility. Karabiner holds it and its children sometimes inherit it, but not dependably,
and the failure is silent: the script runs to completion and nothing moves. Three data points so
far. The Notion archive rule's `mouse-click.js` posts successfully. The Messages tapback rule's
identical calls were filtered under Karabiner across six traced presses, with `AXIsProcessTrusted()`
false, every accessibility read null, and `CGWindowListCopyWindowInfo` titles redacted — neither
Accessibility nor Screen Recording. And the Claude-app click rules were filtered too: a script
logging its own progress reached the line before its click 14 times while nothing moved on screen.
Why one rule keeps the permission and another does not is still unresolved — but a helper can opt
out of the question by disclaiming responsibility for itself, so that TCC judges the binary rather
than its launcher (see [accessibility-rules.md](accessibility-rules.md)). That is the first spawned helper here whose permission
was the same from a shell and from Karabiner.

**One press settles it, so probe before building rather than after it mysteriously does nothing.**
Have the rule spawn a script that reads the cursor, posts a mouse-moved 80pt away, re-reads, and
logs both. `before=238 after=238 moved=0` is the whole answer. A terminal run proves nothing in
either direction: your shell's permissions are not Karabiner's child's.

**Do not carry a technique, a mechanism, or a failure mode across apps on the strength of one
rule.** `mouse-click.js` works for Notion; that was taken as reason to expect it in the Claude app,
and it does not work there. The reverse inference is just as unsafe: its failure there is not
evidence the Notion rule has stopped working. This cuts wider than it looks — most findings in this
section rest on a single rule in a single app (hover-revealed buttons on Notion, filtered posting
on Messages and Claude, the right-click hold on Messages, the zero-pause menu sequence on Claude).
Each is a real measurement of the case it was taken from and a guess about anywhere else. Read them as
"here is what to probe for" rather than "here is how apps behave", and write down which app a new
finding came from.

**`CGWarpMouseCursorPosition` needs no permission at all.** So a script that only has to *position*
the pointer can leave the clicking to Karabiner's `pointing_button`, which is posted by Karabiner
itself and always works. That is the shape the Messages tapback rule uses, and it is the fallback
whenever posting turns out to be filtered.

**The cursor restore is what drags in the spawn — dropping it removes the whole problem.** Karabiner
can move the cursor but not read it, so putting it back afterwards needs a spawned script, and the
rule must then hold long enough for that script to read the position *before* the warp. That hold
was 200ms of Cmd+P's 300ms and was never big enough (see the tail figures below). Dropping the
restore deletes the spawn, the hold and the race together: Cmd+P and Cmd+Shift+U went from 300ms to
no deliberate delay at all. The cost is that the cursor stays on the button. For a shortcut reached
from the keyboard that is usually the right trade, but it is a visible behaviour change rather than
a pure optimisation — ask first.

**Measure the warp-to-click gap per target; do not carry a value between rules.** Cmd+P's was 100ms,
and 0ms opened the project selector 10 times out of 10 — an always-visible button hit-tests
correctly at the click's own coordinates even though a warp posts no hover event. The Cmd+Shift+P
Create PR button did need its 100ms. Same app, same mechanism, different answer.

**A popup's position can be read rather than predicted.** `CGWindowListCopyWindowInfo` needs no
permission either — without Screen Recording it drops window *titles*, but bounds, owner, and layer
still come back — and a context menu is a window of its own at layer 101. Reading its frame beats
measuring an offset from the click: macOS pins a menu above the bottom of the screen when it will
not fit below, and the height it pins from grows with the menu's items, so a message carrying a link
puts the menu where a measured offset would miss. Poll for the window instead of waiting a fixed
time — that removes the race rather than tuning it, and a poll that expires tells you the popup
never opened at all.

**Anchor to something you control.** When the target moves with the content — the Messages tapback
bar follows its bubble's width *and* height — do not chase it. A context menu is anchored to the
click instead, so right-clicking a point you picked makes every position downstream fixed.

**Adjacent `shell_command`s in one `to` array collapse to the last one.** Two spawns back to back
run once, not twice, and the survivor is the later one — no error, nothing logged. A probe with five
stamps, the first three adjacent and the last two behind 150ms gaps, recorded only the third, fourth
and fifth. This silently ate every start-marker added for timing and cost two rounds of presses
before it was spotted. Separate them with a `hold_down_milliseconds`, or join them into one
`shell_command` with a `;`.

**If you do write a Karabiner-native click** (`pointing_button`), three non-obvious rules:

- The **last** `to` event is held down until the from key is released, so a trailing
  `pointing_button` keeps the mouse button down for as long as the chord is held — a press and
  drag, not a click. Put a `vk_none` after it.
- Mandatory modifiers are consumed on Karabiner's virtual keyboard, but the physical keys are still
  down when the click is posted, so it arrives as Shift+Click and extends a text selection across
  the page. Add `"modifiers": []` to the click. This matters more the faster the rule is: 300ms of
  holds used to give you time to release the keys first, so a rule that drops its holds starts
  relying on this clause that was previously coasting.
- A **right-click needs `hold_down_milliseconds`**. The context menu opens on the mouse *down* and
  starts a modal tracking loop; Karabiner releases the button immediately, and an up that lands
  before that loop is installed dismisses the menu again. It failed 5 times in 6 with no hold and 0
  times in 6 with 150ms. A left click needs no hold at all — Cmd+P clicks with none.

**Coordinates** are absolute points on the main display, and only land while the target window is in
its usual position and size — say so in the rule's `comment`. `screencapture -R x,y,w,h` takes
points and returns a 2x image on this machine, which makes the pixel-to-point mapping explicit;
eyeballing a pasted screenshot does not.

**Validate before handing it over**: `karabiner_cli --lint-complex-modifications` on a
`{"title":…,"rules":[…]}` file, and `node build.js karabiner.json` to confirm the README renders.
