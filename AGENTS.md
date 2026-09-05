# Adding keyboard shortcuts (Colemak convention)

I type in the **Colemak** layout. When I ask for a keyboard shortcut and don't say
"physical" or "virtual", I mean the **virtual key in Colemak** — the character
printed on the key I press, as Colemak produces it.

Karabiner's `from.key_code`, however, names the **physical key position** (by its
QWERTY label / scancode). So you must convert the virtual key I name back into the
physical key that produces it in Colemak before writing the rule.

## Rules

- **`from.key_code`** — convert the virtual key I name → physical key (table below).
- **`to` key_code** — leave as the literal virtual key I name; do **not** convert it.
  (Exception: some Claude-app shortcuts need the `to` side converted too — see
  "Exception" below **before** writing any Claude-app rule.)
- **`to` `shell_command`** — no key involved, nothing to convert.
- Digits (0–9) and most symbols are **not** remapped by Colemak — use them as-is on
  both sides.
- **Check the earlier manipulators on the same `key_code` before binding a chord.** Karabiner runs
  the first match, and a `from` with `optional: ["any"]` matches every superset chord: the global
  Cmd+M disable swallowed Cmd+Shift+M until the Claude app was exempted, while the Claude app's
  Cmd+. rule has no optional modifiers, which is what lets Cmd+Option+. fall through to a later rule.

Always add a `description` (and a `(physical key <x> in Colemak)` note when it helps,
like the em-issues rule) so the mapping is self-documenting.

### Worked examples

- "Map `Cmd+D` → `Cmd+U`": virtual `d` is on physical `g`. Rule: `from` key_code
  `g`, `to` key_code `u`. → **Cmd+G → Cmd+U**.
- "em issues on `Cmd+Ctrl+Option+e`": virtual `e` is on physical `k`. Rule: `from`
  key_code `k`. (This is the existing `em issues` rule.)

## Virtual (Colemak) → physical (Karabiner `key_code`)

Only keys that differ are worth memorizing; the rest map to themselves.

| Virtual | Physical | | Virtual | Physical |
|---------|----------|-|---------|----------|
| d       | g        | | n       | j        |
| e       | k        | | o       | semicolon|
| f       | e        | | p       | r        |
| g       | t        | | r       | s        |
| i       | l        | | s       | d        |
| j       | y        | | t       | f        |
| k       | n        | | u       | i        |
| l       | u        | | y       | o        |
|         |          | | ;       | p        |

Unchanged (physical == virtual): `a b c h m q v w x z`, all digits, and Space/Enter/etc.

## Exception: some Claude-app shortcuts need the `to` side converted too

The Claude desktop app (`com.anthropic.claudefordesktop`) re-translates **some** of
Karabiner's output through the macOS Colemak input source
(https://github.com/anthropics/claude-code/issues/68859). For those shortcuts,
emitting the literal virtual key sends the app the wrong character (emitting `u`
arrives as `l`), so the `to` side must be converted with the table above:

- To send the app `Cmd+K`, emit key_code `n` (the `Cmd+J -> Cmd+K, Cmd+3` rule).
- To send the app `Cmd+Shift+U`, emit key_code `i` (the `Cmd+. -> Cmd+Shift+U` rule).

But not every shortcut is affected: the Show Diff rule (`Cmd+Shift+G`) emits a
literal key_code `d` and the app receives `Cmd+Shift+D`, and the `Cmd+Shift+E` rule
emits a literal key_code `e`. The app presumably matches some shortcuts by character
(re-translated) and others by key position (e.g. menu accelerators), but which is
which is only known empirically.

**Shortcut: if converting the `to` side would produce the same key_code as the `from`
side, the app is matching by position — emit the literal virtual key.** A rule whose
two sides are identical does nothing, so a request to "fix" a shortcut that lands on
the wrong physical key can only mean position matching. That is the `Cmd+Shift+E`
rule: I press physical `k` (which types `e`), the app's own shortcut fires on physical
`e` (which types `f` — the key I'd describe as the "F" key), so the rule maps
`from` key_code `k` → `to` literal key_code `e`. Requests of the form "map
Cmd+Shift+<X> (physical) to Cmd+Shift+<Y> (virtual)" where `<Y>` sits on physical
`<X>` are this same case.

Otherwise, when a Claude-app rule's `to` side emits a Colemak-remapped letter: start
with the converted key (two of the four known cases needed it), test, and record which
form worked in the rule's comment. Keys Colemak leaves unchanged (digits, most symbols,
`m`, etc.) look the same either way, which can mask a missing conversion — check the
table even when a rule "already works". This applies **only** to Claude-app rules;
everywhere else, leave the `to` side as the literal virtual key.

## Click rules (move the mouse and click)

**Check the accessibility tree before writing a click rule at all.** Shortwave's Always apply toast
was a coordinate warp-and-click until the tree was dumped, and the target turned out to be an
`AXButton` titled "Always apply" — `karabiner-config-ax-press` reaches it in 26 elements and 29ms,
with no coordinates, no pointer movement, and no dependence on the window's position. See
"Accessibility rules". What follows is for targets the tree does not name.

**Default to Karabiner's own `set_mouse_cursor_position` + `pointing_button`.** It stays inside
Karabiner, so it is faster than spawning a process, and it is fine for any target that is *already
on screen*. Done this way a click rule needs no `hold_down_milliseconds` at all: Cmd+P and
Cmd+Shift+U are a bare warp, click, `vk_none` and fire with no deliberate delay. Cmd+Shift+P and
Cmd+Shift+G still carry the older spawn-and-hold shape described below.

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
than its launcher (see "Accessibility rules"). That is the first spawned helper here whose permission
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

## Accessibility rules (press a control by name)

**When the target moves with the content, stop chasing coordinates and ask the accessibility tree.**
The Copy button under ChatGPT's last response sits wherever the response ends, and the app has no
shortcut or menu item for it (its bindable-shortcut registry was searched). `scripts/ax-press.swift`,
built as `scripts/bin/karabiner-config-ax-press`, finds a control by role and label in the app's
focused window and `AXPress`es it: no coordinates, no pointer movement, no restore, and the press
lands on an element scrolled out of view. Two rules use it: ChatGPT's Cmd+Shift+C (29-38ms from the
helper starting to the press landing, 88 elements visited of 5297) and the Claude app's Cmd+Option+.
(57-78ms, 497 elements), which performs AXShowMenu rather than AXPress — see "Context menus".

**Chromium puts aria-labels in `AXDescription`; tooltips are not in the tree at all.** The button the
app's tooltip calls "Copy response" is `AXDescription="Copy"`, and code-block copy buttons carry the
same label, so the rule discriminates by a sibling (`--sibling "Good response"`), not by depth or
frame. `--dump` lists every labelled element with roles and frames; read it before guessing a label,
and query a substring — an empty query matches nothing.

**A target that exists for only a few seconds is inspected by polling `--dump` while it is up.** A
toast cannot be dumped on demand, so loop the dump (~1.1s per pass here) and ask for one press that
triggers it. Shortwave's Always apply toast stayed in the tree for 44 consecutive dumps (~45s), wide
enough that the rule needs no `--wait`. Query one letter (`a`) when the wording is unknown and diff
the dumps for what appeared. The empty query is the trap the paragraph above names: a first run of
400 dumps passed `""` and could not have found anything.

**Shortwave (`com.electron.shortwave`) exposes its web content like any Chromium tree** — 1122-1450
elements, `AXWebArea` present, `AXButton AXTitle="Compose"`, `AXImage AXDescription="Avatar for …"`.
The Always apply toast's button is titled "Always apply" and is unique in the window; it sits at the
end of the document (element ~1128 of ~1200 forward), so the default reverse walk finds it in 26.

**Accessibility permission goes to the helper itself, which is what makes it predictable.** TCC
judges a command-line tool by whatever launched it — a terminal, or Karabiner — which is why the same
script can post events from one rule and not another. The helper re-spawns itself with
`responsibility_spawnattrs_setdisclaim`, the private posix_spawn attribute Chromium uses for its own
helpers, so the child is judged as the binary wherever it was launched from: granted once in System
Settings, it reported trusted=true from a shell and from Karabiner alike. The grant is keyed to the
binary's ad-hoc signature, so every rebuild needs it granted again — six rebuilds, six regrants in
the session that built it; `scripts/build-ax-press.sh` has the steps, and a self-signed signing
certificate is the fix if that ever becomes routine.

**A helper that carries its own grant is a confused deputy, so it presses only for Karabiner.** The
disclaim hands the binary's Accessibility to whatever runs it, which would let any process running as
the user press any labelled control in any app with no interaction — where abusing Karabiner's own
input injection at least needs a rule written into `karabiner.json` and a keypress to fire it. So the
helper refuses to press unless Karabiner's `Karabiner-Console-User-Server` is among its ancestor
processes (checked by full path, under root-owned `/Library`, not by name), logs to one fixed file
under `.claude/` rather than a path from its arguments, and leaves `--dump` and `--dry-run` usable
from a shell, since reading labels is the modest end of what it can do. Testing a real press
therefore always goes through the rule. Name the binary so the
Accessibility list says whose it is (`karabiner-config-ax-press`, not `ax-press`), and make the tool
take everything as arguments so a new rule never needs a rebuild. A new *label* never does; a new
*capability* does — `--action` and `--label-from` were one, `--wait` and `--key` another — and each rebuild costs a
regrant, so add an option general enough that the rule after it is arguments again.

**Sequencing anything after a helper call is the helper's job.** Karabiner cannot wait on a
`shell_command`, so a key_code after one is only ever a fixed hold behind a spawn — the race the helper
was brought in to remove. Two calls joined with `&&` in one `shell_command` sequence themselves, and
`--wait` lets the second poll for a control the first is still bringing on screen (the Archive item of
a dropdown, found 16-31ms in). A trailing key chord goes through `--key`, which the helper posts as a
CGEvent (its Accessibility grant covers posting) once the pressed control has left the tree — the menu
closing is the click having been handled, 118-580ms after the press in the Claude app.

**Chromium exposes none of the page until an assistive client shows up, and what counts as showing
up is asking the *application object* for its role.** A freshly launched ChatGPT — and Brave —
answers with the window chrome only: 12 elements, no `AXWebArea`, and no amount of walking windows,
reading labels, hit-testing, focusing the window or clicking into it changes that (three fresh
instances, one watched for twenty minutes). Chrome's and Electron's NSApplication subclasses both
switch accessibility on in `accessibilityRole`, citing Apple's guidance for non-VoiceOver clients, so
one `AXRole` read of the application element is the switch: the instance that had ignored everything
else exposed its tree 124ms after it. The helper does this first thing; the sporadic exposures seen
before it did were other clients on the machine happening to ask. The switches a client used to set
are dead in ChatGPT *and* Brave — Electron's `AXManualAccessibility` is unsupported (-25205),
`AXEnhancedUserInterface` returns not-implemented (-25208), and Chromium 151 no longer watches it (it
observes `NSWorkspace.voiceOverEnabled` instead) — but the Claude desktop app (1.40609.0) still
accepts `AXManualAccessibility` (returned 0) and exposed its tree between 1 and 2.5s after the first
query. The app decides; the role read is the only switch known to work everywhere it has been tried,
and whether a freshly launched Claude app exposes its tree on the first press is untested.
`--force-renderer-accessibility` on the command line also works; the env var the app reads for extra
switches is dev-build-only. Read the source
before another round of probing: the answer was one fetch of `chrome_browser_application_mac.mm`
away, after five rebuilds spent guessing. Untested: Chromium can drop accessibility for a web
contents hidden for five minutes or more (`AccessibilityDisabler`), so a press that logs
`tree_exposed=false` after the window sat behind others is the first thing to suspect.

**A clipboard write needs the document focused.** AXPress reports success either way, but the page's
clipboard write is refused when the window is not frontmost, and ChatGPT shows a "couldn't copy"
toast. A rule triggered from the app itself is fine; a shell test with another app in front does not
test the copy.

**Two traps in walking the tree.** It is not always a tree: a freshly launched ChatGPT answered with a
child that led back to an ancestor, and a naive recursion overflowed the stack (SIGSEGV, "excessive
recursion") — keep the ancestor path and skip anything on it. And an app with no window open answers
`AXFocusedWindow` with its own application element; insist on `AXRole == AXWindow`.

**Search from the end of the document.** Reverse pre-order — children last to first, then the node —
returns the last match in document order after visiting the composer and the last turn rather than
the whole conversation. If the newest turn is a user message or the response is still streaming, the
previous response's button is the last one; the rule's comment says so rather than guarding it.

**A second instance of the app is a clean process to experiment on.** Launching the binary directly
with its own `--user-data-dir` (and, for this app, `CODEX_ELECTRON_USER_DATA_PATH`) sidesteps the
process singleton, so the user's running instance and its Codex sessions are untouched. It signs into
the same account, so delete the scratch profile afterwards.

**The tree does not say which item is current when the app keeps that in `data-*` attributes.** The
Claude app's sidebar rows are identical to accessibility: `AXSelected` 0, `AXARIACurrent` empty, and
`AXDOMClassList` — Chromium exposes the class attribute, and `AXDOMIdentifier` the id — the same
Tailwind variant list on every row (`data-[selected=focused]:bg-…`), because the state lives in a
`data-selected` attribute nothing exposes. What did name the current chat was another labelled
element: the header's `"<chat>, rename session"` button. `--label-from "{}, rename session"` reads it
and fills the `{}` in the target label (`"More options for {}"`). When the target is "the current
X", look for a label elsewhere on the page that spells X out.

**Pick the walk direction from where the target sits.** The default reverse walk is right for a
button under the last response; for a sidebar at the *start* of the document it would cross the
whole transcript first. `--first` reached the Claude app's row after 497 elements, 57-78ms.

**`--dry-run` from a shell verifies the target before the lock is taken.** It resolves `--label-from`
and finds the element without pressing, so the live-config lock is held only for the presses
themselves (110ms, `label="More options for 💰 TSLA exit strategy"`).

**Claude desktop app 1.40609.0, Code tab — what the sidebar looks like to accessibility.** The
sidebar is an `AXGroup` (subrole `AXLandmarkComplementary`, description `Sidebar`). Each chat row is
an `AXButton` titled `"<status> <title>"` (`Idle`, `Running`, `Awaiting input`), with an
`AXPopUpButton` described `"More options for <title>"` beside it — hover-revealed (`opacity-0`,
`pointer-events-none`) yet present in the tree, and `AXShowMenu` on it opened the row's menu. The
session header carries an `AXButton` described `"<title>, rename session"` and, at the top right of
the main pane, an `AXPopUpButton` described `"More options for <title>"` -- the **same label as the
sidebar row's button**, so a `--first` search for it finds the row while the sidebar is visible and the
header button once it is hidden; `AXShowMenu` on the header button gets Electron's default
Copy/Select All menu, not the chat's. `AXPress` on it opens the chat's dropdown (Archive and the rest)
with no sidebar needed, which is what the Cmd+Shift+E archive rule uses. Titles may begin with an
emoji. The Chat tab's header was not inspected.

## Context menus (open the right-click menu without the mouse)

macOS offers no keyboard route to a web app's context menu. Chromium compiles Shift+F10 out on Mac
(`web_frame_widget_impl.cc`: `is_shift_f10 = false` under `BUILDFLAG(IS_MAC)`), a menu bar cannot
name a context-menu item, and the Claude app's own shortcut list (Cmd+/) has nothing for it — the
request was anthropics/claude-code#60551, auto-closed. What is left is the accessibility tree.

**`AXShowMenu` is a right-click.** Chromium advertises it on every web-content node
(`ui/accessibility/platform/browser_accessibility_cocoa.mm`: `SupportsShowMenuAction` is true for
web content, `PerformShowMenuAction` calls `ShowContextMenu`) and implements it by dispatching a
`contextmenu` event at the element, which a context-menu component handles exactly as it handles the
mouse. `ax-press … --action AXShowMenu` is the rule shape; the Claude app's Cmd+Option+. is its one
user (3 presses, 3 menus). Nothing hovers, nothing moves, and the element may be hidden.

**Once open, the menu is the app's own.** The Claude app's chat menu takes arrows, `1`-`9` inside
the Add to project and Move to group submenus, and its single-letter accelerators, so opening it was
the whole gap. Check what the menu already does from the keyboard before building anything past the
open.

**Untested: the PC Menu key.** Chromium keeps the unmodified `VKEY_APPS` path on Mac (macOS keycode
0x6E, Karabiner `key_code` `application`), which sends `contextmenu` to the *focused* element. It
needs the target to hold DOM focus, which a sidebar row does not once the chat is clicked into, so it
was not tried. It is the route to probe when the target is a focused control.

## Menu bar rules (drive the app's own menus)

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

## Pauses (`hold_down_milliseconds`)

**Never add a pause on speculation.** Not "just to be safe", not "this probably wants a moment", not
a round number carried over from a rule that looked similar. A constant in a rule is paid on every
press, forever, by the person pressing it, and an unnecessary one is invisible: nothing fails, so
nobody goes back to check. A pause that is genuinely needed announces itself the first time it is
missing, and costs one round of presses to add.

**Start at zero; adjust up only on evidence.** The default for any new pause is that it does not
exist. Add one when the rule has been *observed* to fail without it, and size it to the failure that
was observed rather than to how alarming the failure felt. Err fast in the meantime.

**Measurement has changed every constant it has touched here, in both directions.** Four went to
zero: the menu-bar sequence shipped at 150/150/150/120ms and passed 20/20 at 0; Cmd+P's warp-to-click
gap was 100ms and passed 10/10 at 0; Cmd+Shift+G's two gaps were 100ms each and passed 10/10 at 0/0.
One was too *small*: the 200ms covering a script spawn, measured p50 101ms against a 963ms tail, and
fixed by removing the spawn rather than by raising it. Exactly one survived contact unchanged — the
150ms hold on a right-click, which failed 5 times in 6 without it. That is what an earned constant
looks like: a failure count at a specific value, written next to it.

**And one turned out not to be a constant problem at all.** The archive rule's 120ms before Enter
failed 3 times out of 3 under CPU load. It went to 350ms on the first measurement, then back to 120ms
once the query it types was shortened from `archive` to `arch` — because what it was short against
was the app's backlog from its own seven keystrokes, and four keystrokes cost less. Ask what a pause
is waiting *behind*, not only how long the thing it waits *for* takes; the rule's own input is part
of the answer. A too-short pause also fails intermittently and blames itself on something else, which
is how that rule went a long time looking like a flaky app rather than a wrong number.

**That one then failed in ordinary use, the day it shipped.** 19 hand presses under a deliberate CPU
throttle put the requirement at 17-83ms and the floor at 100ms; 120ms shipped; a real press beat it
within hours, and the hold is now 150ms. Nothing in the measurement was wrong — it simply never
reached the tail, which is the documented limit of ~20 hand presses, and the limit was written next
to the number before it bit. Two things follow. A measured floor bounds the *typical* case; headroom
over it is a separate decision, and on a rule whose failure costs something, the floor is the wrong
place to ship. And when a rule with an earned constant misfires, raise that constant first — the
floor is not what is in doubt, and re-deriving it burns presses to re-learn what is already known.

**A hold is not always the slack the app sees — seen in the Claude app, untested elsewhere.**
`hold_down_milliseconds` delays Karabiner's *emission*, not the app's *processing*. The Claude app
renders a burst of keystrokes a few at a time (its palette field steps through visibly distinct
partial widths), so it is still draining them when the next event arrives, and the gap it experiences
is shorter than the constant — shrinking further under load, exactly when the pause was needed.
There, under CPU throttle: a 120ms hold after seven letters delivered Enter 67ms after the last
letter rendered, the other 53ms eaten by backlog; four letters cut that cost to about 30ms. Two
consequences *in that app*: count the keystrokes a rule sends as part of its cost, and size a hold
against a measurement taken at the app rather than the number in the config. Whether any other app
queues input this way has not been checked here, and the menu-bar sequence — which floors at zero
after 20 presses — is evidence that not everything does. Also measure under load: idle, that rule's
race did not reproduce at all in 15 presses.

**Say so when a value is un-searched.** Cmd+Shift+P keeps a 100ms gap not because it was measured but
because its target is the Create PR button and a binary search would fire it once per press. Its
comment says that outright, so the number is not mistaken later for a floor.

## Testing a change (worktrees + the live-config lock)

`~/.config/karabiner/karabiner.json` is both the main checkout's working file and the only file
Karabiner-Elements reads. Worktrees keep their own copy, which Karabiner ignores — so **editing is
parallel, testing is serial**. Testing also contends for my keyboard: two sessions cannot both ask
me to press a key.

- Develop in a worktree under `.claude/worktrees/`. Leave the main checkout as the live slot.
- **Never copy a branch config over the live file directly.** Testing goes through the mutex in
  `scripts/karabiner-test-lock.sh`, which snapshots the live config first and restores it
  byte-exactly on release — including uncommitted work.
- Acquire late, release fast: writing the rule, the Colemak conversion, and `npm run build` need
  no lock. Take it only for the keypress test.
- Run `./scripts/karabiner-test-lock.sh status` before committing `karabiner.json` from the main
  checkout. While another worktree holds the lock, the live file contains *their* rules.
- Run the lock script with an explicit `cd` into the worktree. It derives the owner from the shell's
  cwd, and the Bash tool's cwd drifts back to the main checkout mid-session: a lock taken from there
  snapshots the live file, and `install karabiner.json` then compares the live file with itself and
  reports "already identical" while installing nothing.
- **Edit `karabiner.json` in place; never reformat it.** The file is Karabiner's own 4-space format
  with short arrays inline, and both `json.dump` and `prettier` (the repo's `.prettierrc.json` is
  2-space) rewrote the whole file — 2016 insertions for a 4-line change. Patch the lines, and find a
  block's closing bracket by counting brackets: matching an indented `]` finds the wrong one and
  silently eats the lines between.
- `set -e` is inert in the Bash tool: a failing `false`, or a heredoc'd `python3` that raises, does
  not stop the rest of the command line (probed both). Chain a check and the steps behind it with
  `&&`; the learnings commit shipped past its own failed content check this way.

Full procedure: the **test** skill. Landing it on main: the **ship** skill.

## Session titles

The chat sidebar shows a status dot (running / awaiting input / idle) and a branch glyph for
worktree sessions; neither can be set from here — `set_session_title` takes a title string and
nothing else. So a **single leading emoji on the title** is the only lever, and it is spent on
what the app cannot know: where the work stands.

| Prefix | Means |
|---|---|
| 🔒 | holds the live-config test lock right now |
| 🧪 | rule verified by keypress, still on a branch — shippable without re-testing |
| 🚀 | merged to `main` and pushed |
| 🚙 | parked: the work is sound and waiting on the user (a decision, a batch of presses) |
| 🪦 | dead end — kept for the findings, not to resume |
| 📚 | learnings written into AGENTS.md; nothing left to extract |

These are **stages, not flags**: exactly one prefix at a time, and setting a new one replaces
whatever was there. Only one reads cleanly at sidebar width, and 🚀 after 🧪 is noise — the later
stage implies the earlier.

The lifecycle 🔒 → 🧪 → 🚀 is set by skills (`test` acquires and releases; `ship` merges), so it
stays true on its own. The rest are set by hand when they apply, and nothing reconciles a title
against reality — an abandoned session keeps whatever prefix it had. 🚙 in particular is worth
setting before handing back on a long-running investigation: the idle dot cannot tell "waiting on
you" from "given up on".

## Debugging rules that misbehave

Learned the slow way on the Notion archive and Messages tapback rules:

- **Instrument inside the script.** It runs in the context that holds the permissions, so having it
  append what it saw — pointer position, whether the popup's window existed, how long it waited —
  turned "it stops short sometimes" into "the right-click produced no menu in 5 of 6, within 300ms"
  in a single round of presses. Ask the user for a batch and count, rather than one press at a time.
- **Capture the screen from your own shell, not from the rule.** The shell has Screen Recording
  where the Karabiner-spawned script may not, so a capture loop gated on the target app being
  frontmost collects the pixels to measure while the user drives the UI. Measure the result in
  code — colour runs along a row and column give exact edges; eyeballing a crop does not.
- **Use a control.** Clicking an always-visible button (the sidebar search icon) with the same
  sequence separated "synthetic clicks work in this app" from "this button is special" in a single
  press, after many rounds of theorizing had not.
- **Small samples lie near a threshold.** Once failures are probabilistic, "worked every time" over
  a handful of presses cannot distinguish 100% from 90%. Three configurations passed a short test
  and then failed in use, so a pass at one value is a data point, not a floor. This cuts against
  *removing* a pause on thin evidence as much as against keeping one — the default is zero, but a
  10/10 at zero is what licenses shipping it, not a hunch that the pause looked pointless.
- **Seek the floor by binary search, and ship the floor.** Picking a value that feels safe and
  stopping there is guessing dressed up as caution: it leaves the real cliff unmeasured, so every
  later misfire reopens the whole question instead of moving a known number. Drive each pause down
  until it actually fails, with enough trials per value that a probabilistic failure shows up, and
  use what you measured. Do not hand-wave a split between pauses that "wait on a real transition"
  and ones that do not; measure each. Cmd+Shift+G's click-to-keystroke gap was predicted to be the
  real one of its two, on the reasoning that it waits for focus to move. It measured 0/0 alongside
  the other. A transition being real does not mean anything is racing it.
- **A pause you cannot point at a measurement for is a race, not a margin.** The 200ms hold the
  click rules used to cover `restore-mouse-position.js` reading the cursor measured p50 101ms over 400
  samples — but the tail reached 300ms and once 963ms, so it silently loses a percent or two of
  presses. It reads as a comfortable 2x margin and is really a coin flip against the tail. Measure
  the distribution and size the constant to that, not to the typical case — or remove the spawn the
  constant is covering, which is what actually fixed those rules.
- **When the last keystroke is destructive, measure a marker key instead.** That is where the archive
  rule's floor came from; the method, and the traps in it, are in "Measuring against the Claude app
  with video" below.
- **Bisect the underlying UI, not the rule — if you can post events at all, which right now you
  cannot.** Karabiner cannot be triggered synthetically: it grabs the physical device, so injected
  CGEvents never reach its rules. The transitions the pauses cover are plain macOS behaviour and
  could be replayed and bisected automatically, turning a floor search from dozens of hand presses
  into an unattended sweep — but that needs Accessibility, and this machine does not grant it:
  `osascript` gets "not allowed to send keystrokes" (System Events error 1002), while Automation to
  System Events *is* granted, so a harmless call like `get name of first process` succeeds and makes
  the permission look present. Check with an actual keystroke before planning a sweep around it. When
  it is unavailable, every trial costs a human press — see the video section for how to spend them.
- **A model that needs revising every round is the signal to stop tuning.** Five plausible models
  each explained the evidence and then broke. Stop turning knobs and find a decisive measurement.
- **Measure end-to-end.** A latency figure summed from a script's sleep constants was wrong about
  where the time actually went; timing the real command settled it in one step.
- **A helper that builds its log path from `getenv("HOME")` once exited non-zero and wrote nothing,**
  so the instrumentation failed silently and looked exactly like the rule never firing. The ChatGPT
  rule's `shell_command` has since logged `HOME=/Users/raine`, so the shell does get `$HOME`; what the
  earlier helper saw is unexplained. Hardcode absolute paths in anything a rule spawns anyway — it
  costs nothing — and put a `date >> log` marker in the same `shell_command` (joined with `;`) so
  "never fired" and "fired and died" are told apart in one press.
- **Instrument the config that ships, not a copy of it.** A probe pointing at a scratch copy of
  `mouse-click.js` failed while the open question was whether the real one worked — that adds a
  variable instead of removing one. Install the actual candidate and measure that.
- **A listen-only `CGEventTap` from your own shell is not an instrument here.** `CGEventTapCreate`
  returns a valid port and then delivers nothing, not even ordinary clicks, so an empty log reads as
  "the click never happened" when it means "the tap never worked". Prove an instrument sees a known
  event before trusting its silence. Bracketing the rule with its own timestamps is more reliable.
- **Two JXA traps that only bite once the call works.** `String(someNSString)` yields the literal
  `[id __NSCFString]` — use `ObjC.unwrap()`; it silently replaced a trace log's contents. And an
  untyped `Ref()` throws `Ref has incompatible type` when an accessibility call *succeeds*, so a
  probe that returns an error for lack of permission looks healthy and only breaks once granted.

## Measuring against the Claude app with video

Where the archive rule's floor came from. The capture and analysis mechanics are general; **every
number and every claim about palette behaviour below is the Claude desktop app only**, and none of it
has been checked against another app.

**What the palette does (Claude app).** Typing into Cmd+K updates in two stages: the field and the
quick actions take the query immediately, while the contextual `Archive "<title>"` / `Delete
"<title>"` rows arrive only once the query resolves. Until they land, Enter belongs to `New chat
"<query>"` — its Enter badge turns red — and firing it posts the query as the first message of a new
chat. Lag from the last letter rendering to Archive owning Enter: 0-50ms idle over 15 presses typing
`archive`, and 17-83ms at 100% CPU load over 19 presses typing `arch`.

**Clicking the row is not the safer alternative there.** When the chat's title matches the query,
`Delete "<title>"` renders directly under `Archive "<title>"` — Archive spans roughly y 232-255pt and
Delete starts at ~257pt, with the window at 0,34 735x922. A click 13pt low deletes the chat. Before
the rows land, that same point is over the inert "Quick actions" header, so the early failure is
harmless and the late-aim failure is not.

**Presses are the scarce resource; there is no synthetic input.** Karabiner grabs the physical device,
so injected events never reach its rules, and `osascript` is refused keystroke permission on this
machine (System Events error 1002 — Automation to System Events is granted, Accessibility is not).
Every trial costs a human press, so design for information per press.

**Marker probe.** Replace a destructive final keystroke with a harmless one at the same offset — for
the archive rule a `z`, which only extends the query — and read whether the UI was ready in the frame
the marker landed in. Read *only* that frame: anything the marker itself changes (the `z` restarts
the palette's query) makes every later frame a measurement of the probe, which inflated a "the row
needs 150-300ms" figure here before it was caught. Check the proxy against the real action in both
directions before trusting it. Here it predicted 3/3 failures that the real Enter reproduced, and the
value it produced was then confirmed by hand with the real Enter — worth doing separately, because
Enter runs the palette's command handler while `z` goes into the text field, so a marker that passes
is not by itself proof that the real key will. A hand confirmation is a handful of presses, though:
it rules out a broken proxy, not a rare false negative. Only ordinary use over weeks tests that.

**One generous delay beats a sweep.** A sweep spends presses to learn one bit each, and censors
exactly the presses that matter: a press at 50ms can never reveal that it needed 90. Run every press
at a delay high enough that all of them pass, and compute what each one *needed* — nominal minus the
gap between "ready" and the marker. 15 presses that way gave a full distribution (17-67ms); the
sweep's 19 gave four buckets of five with the interesting values censored.

**Include an arm that must fail.** The 0ms arm was a positive control. When it *passed*, the detector
was wrong rather than the app — the red badge's absence covers both "Archive owns Enter" and "the
palette has not reacted to the query yet". Without that arm the sweep would have read as clean.

**Encode the arm in the pixels.** Timing alone did not separate the delay arms under load; they
blurred into a continuum. Giving each arm a different number of marker keys (1/2/3/4 `z`s) made the
final query width name the arm exactly, and cost nothing, since the verdict is read at the first
marker's frame.

**Capture recipe.**

```
ffmpeg -f avfoundation -capture_cursor 0 -framerate 60 -i "3:none" \
  -vf "crop=W:H:X:Y" -c:v libx264 -preset ultrafast -crf 20 out.mp4
```

Device index from `-f avfoundation -list_devices true -i ""`. Crop in *screen pixels* (2x points on
this display) to the smallest region that answers the question — 980x210 here. A full-window 60fps
capture is heavy enough to perturb what it measures, and a `screencapture` shell loop tops out at
8-10Hz, far too coarse for a 17ms transition. `-vsync` no longer exists; it is `-fps_mode`.

**Extract frames with `-fps_mode passthrough` and take times from pts.** Without it ffmpeg pads to CFR
and frame indices stop matching `ffprobe -show_entries frame=pts_time` — 8069 against 8033 in one run
— which silently shifts every measurement. The capture also drops frames under load (51fps of a
requested 60), so index x 16.7ms is not a clock.

**Detector traps, each of which produced a confident wrong answer first.**

- A row's mean brightness mixes its dark background with its white text and lands *between* the two
  states. Use the minimum row-mean over the band, so the row's dark padding is what is detected:
  12 against 29 here, unambiguous.
- Bound every search to its own trial. A "when did the row appear" search that runs past the palette
  closing finds the *next* press and reports 1.6s.
- Walking back from the marker to a plateau finds its last frame, not its first. The reference has to
  be the first.
- Content behind the palette imitates a trial. Require a trial to pass through the states a press must
  pass through — empty field, then the query's width, then the marker — and require the row to start
  absent.

**What hand pressing cannot reach.** 17ms of resolution at 60fps, and ~20 presses characterise a tail
to roughly the 1-in-20 level. The far tail is not measurable this way. Say so next to the number
instead of implying the floor is airtight.

## Communication

- Report outcomes tersely: what was found, what was done — "1 instance: AGENTS.md. Removed and amended." Skip process narration and thoroughness reassurances; verify silently and state conclusions.
- Report a change as a bulleted list of fragments, not prose. "Default to warp-and-click." — not a paragraph restating what the new guidance says and why it matters.
- One idea per bullet. Name the change, not its justification: "Cost noted (~150ms)", "Diagnostic added".
- Do not re-explain reasoning already established in the conversation, and do not re-argue a correction while reporting it. It was agreed; just say what landed.
- Omit anything with no consequence: "working tree clean", "JSON valid", "lint passed", "no incidental changes". Verification is assumed. Report a check only when it *failed* or changed what you did.
- Do not narrate git state — branches, refs, what is checked out where, what will conflict, who
  must rebase. git refuses anything unsafe and conflicts are the agent's to resolve, so a deferred
  fast-forward is one fragment: "Local main left at 95f33ab -- leaving the pull to the other
  branch." Not a paragraph on why it deferred and what the other branch faces.
- Keep caveats and side observations to one line each.
