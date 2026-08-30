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
Why one rule keeps the permission and another does not is still unresolved.

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
Each
is a real measurement of the case it was taken from and a guess about anywhere else. Read them as
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

Full procedure: the **test** skill. Landing it on main: the **ship** skill.

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
fixed by removing the spawn rather than by raising it. Exactly one survived contact — the 150ms hold
on a right-click, which failed 5 times in 6 without it. That is what an earned constant looks like:
a failure count at a specific value, written next to it.

**Say so when a value is un-searched.** Cmd+Shift+P keeps a 100ms gap not because it was measured but
because its target is the Create PR button and a binary search would fire it once per press. Its
comment says that outright, so the number is not mistaken later for a floor.

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
- **Bisect the underlying UI, not the rule.** Karabiner cannot be triggered synthetically — it grabs
  the physical device, so injected CGEvents never reach its rules — but the transitions the pauses
  are covering are plain macOS behaviour and can be replayed with granted synthetic events and
  bisected automatically. That turns a floor search from dozens of hand presses into an unattended
  sweep. Detect success from something pollable rather than a screenshot per trial.
- **A model that needs revising every round is the signal to stop tuning.** Five plausible models
  each explained the evidence and then broke. Stop turning knobs and find a decisive measurement.
- **Measure end-to-end.** A latency figure summed from a script's sleep constants was wrong about
  where the time actually went; timing the real command settled it in one step.
- **Karabiner spawns `shell_command` with no `$HOME`.** A helper that builds its log path from
  `getenv("HOME")` exits non-zero and writes nothing, so the instrumentation fails silently and looks
  exactly like the rule never firing. Hardcode absolute paths in anything a rule spawns, and check it
  with `env -i /bin/sh -c '…'` before spending a round of presses on it.
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

## Communication

- Report outcomes tersely: what was found, what was done — "1 instance: AGENTS.md. Removed and amended." Skip process narration and thoroughness reassurances; verify silently and state conclusions.
- Report a change as a bulleted list of fragments, not prose. "Default to warp-and-click." — not a paragraph restating what the new guidance says and why it matters.
- One idea per bullet. Name the change, not its justification: "Cost noted (~150ms)", "Diagnostic added".
- Do not re-explain reasoning already established in the conversation, and do not re-argue a correction while reporting it. It was agreed; just say what landed.
- Omit anything with no consequence: "working tree clean", "JSON valid", "lint passed", "no incidental changes". Verification is assumed. Report a check only when it *failed* or changed what you did.
- Keep caveats and side observations to one line each.
