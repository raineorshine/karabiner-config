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
on screen* — the four Claude-app click rules work this way.

**Switch to the script when the target only appears on hover.** `set_mouse_cursor_position` *warps*
the cursor without posting a mouse event, and Chromium/Electron apps track their hover target from
events rather than from where the cursor is. A button that exists only while its row is hovered
therefore paints as hovered while the click hit-tests against the element underneath and activates
that instead. Every workaround fails: extra warps, one-point nudges, two-stage hovers, `mouse_key`
motion, double clicks, and dwell tuning in either direction (130ms worked, 250ms was flaky, 400ms
failed outright). Only real motion fixes it.

`scripts/mouse-click.js <x> <y> [--no-click] [--no-restore]` walks the pointer there with real
`CGEvent`s, clicks with the modifier flags cleared, and restores the cursor. The Notion archive rule
uses it; it costs roughly 150ms of process startup and settle, which is why it is not the default.

**Diagnosing which case you are in:** click something always-visible nearby with a plain warp and
click. If that works and your target does not, the target needs the script.

**`CGEventPost` works when Karabiner runs it, not when you do.** Posting CGEvents needs
Accessibility permission. `osascript` does not have it, but Karabiner does and the processes it
spawns inherit it. Run the same command from a terminal and the events are silently filtered and
the cursor never moves — that is *not* evidence the approach fails. Test a mechanism in the context
where it will actually run before ruling it out.

**But do not assume that inheritance holds — probe it.** In the Messages tapback rule the same
`CGEventPost` calls were silently filtered *under Karabiner*: a posted mouse-moved event never moved
the pointer, across six traced presses, while the Notion rule's `mouse-click.js` kept working from an
identically shaped `shell_command`. That script also saw `AXIsProcessTrusted()` return false, every
accessibility read return null, and `CGWindowListCopyWindowInfo` come back with window titles
redacted — so it had neither Accessibility nor Screen Recording. Why one rule keeps the permission
and the other does not is unresolved. Have the script log what it actually got before building on it.

**`CGWarpMouseCursorPosition` needs no permission at all.** So a script that only has to *position*
the pointer can leave the clicking to Karabiner's `pointing_button`, which is posted by Karabiner
itself and always works. That is the shape the Messages tapback rule uses, and it is the fallback
whenever posting turns out to be filtered.

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

**If you do write a Karabiner-native click** (`pointing_button`), three non-obvious rules:

- The **last** `to` event is held down until the from key is released, so a trailing
  `pointing_button` keeps the mouse button down for as long as the chord is held — a press and
  drag, not a click. Put a `vk_none` after it.
- Mandatory modifiers are consumed on Karabiner's virtual keyboard, but the physical keys are still
  down when the click is posted, so it arrives as Shift+Click and extends a text selection across
  the page. Add `"modifiers": []` to the click.
- A **right-click needs `hold_down_milliseconds`**. The context menu opens on the mouse *down* and
  starts a modal tracking loop; Karabiner releases the button immediately, and an up that lands
  before that loop is installed dismisses the menu again. It failed 5 times in 6 with no hold and 0
  times in 6 with 150ms. A left click needs no hold, which is why the older rules do not carry one.

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

This is the opposite of the click rules above, and the distinction is worth holding onto: a
synthetic click races a live UI that may not have drawn the target yet, so it needs a real wait or a
poll. A queued key event does not. Before reaching for `hold_down_milliseconds`, ask which of the
two you are actually in — the constants only belong in the first.

(The 20 presses were unloaded. If a menu rule ever misfires, suspect a busy renderer delaying the
menu, and measure before adding a constant back.)

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
  and then failed in use, so a pass at one value is a data point, not a floor.
- **Seek the floor by binary search; add the margin once, at the end.** Picking a value that feels
  safe and stopping there is guessing dressed up as caution: it leaves the real cliff unmeasured, so
  every later misfire reopens the whole question instead of moving a known number. Drive each pause
  down until it actually fails, with enough trials per value that a probabilistic failure shows up,
  and only then add a fixed margin over the measured floor. Do not hand-wave a split between pauses
  that "wait on a real transition" and ones that do not — measure each.
- **A pause you cannot point at a measurement for is a race, not a margin.** The 200ms hold the four
  click rules use to cover `restore-mouse-position.js` reading the cursor measured p50 101ms over 400
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
