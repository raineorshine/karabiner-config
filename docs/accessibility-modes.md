# Accessibility modes (why a press can log success and do nothing)

Chromium serves an app's web content to accessibility clients at more than one level of detail, and
an `ax-press` search can succeed at a level where a press cannot. That is what made the first
Cmd+Shift+E after every Claude app launch do nothing, and it holds for every AXPress rule in an
Electron app that takes `AXManualAccessibility`. The helper now waits for the switch
(`fullModeDelay` in `scripts/ax-press.swift`).

## The moving parts

**Chromium turns accessibility on in stages, and the early stage is enough to search.** Reading the
application object's role turns on native APIs, and reading the web contents container's role turns
on basic web accessibility (`kNativeAPIs | kWebContents`) — see "Chromium exposes none of the page"
in [accessibility-rules.md](accessibility-rules.md). Basic mode serializes roles, names, frames
and class lists, so a walk finds its target and `--dump` looks complete. Complete mode adds
`kInlineTextBoxes`, `kExtendedProperties` and `kScreenReader`.

**In basic mode every AXPress on a web control is dropped, and the call still returns success.**
`BrowserAccessibilityManager::DoDefaultAction` returns without doing anything when the node has no
default action verb (crbug.com/348328060), and Blink serializes that verb only with
`kExtendedProperties`: `AXObject::Serialize` returns before `SerializeOtherScreenReaderAttributes`
without it. The log says `found=true pressed=true` and the menu never opens. AXShowMenu, attribute
writes (`--set`) and `--click` do not go through the verb, so they work in basic mode.

**Electron switches complete mode on 2s after a client asks, and every ask restarts the countdown.**
Setting `AXManualAccessibility` (or `AXEnhancedUserInterface`) on the app schedules it
(`enableScreenReaderCompleteModeAfterDelay` in `shell/browser/mac/electron_application.mm`, a
debounce written for VoiceOver's quick on-and-off); a set before it fires pushes it back, and once on
it stays on until the app quits or a client sets the attribute (or `AXEnhancedUserInterface`)
to `false` while no set of `true` is pending. The helper sets `AXManualAccessibility` at the start of every
request, so its first request into a freshly launched app starts the countdown and presses about 50ms
later, in basic mode. On the Claude app's ⋮ menu, presses stopped being dropped just past the 2s mark
(the sweep is in `fullModeDelay`'s comment). ChatGPT and Brave refuse the attribute (-25205), so the
helper never brings them this switch.

**First seen on Claude 1.52386.6 and still true on 2.110.1 (Electron 44.2, Chromium 152).** On
1.52386.3 the first press after a launch worked, and the helper's sets left no `[a11y]` line in the
app's log (below). Whether Electron's handling of the attribute or Chromium's gating of the press is
what changed was not pinned down.

## The fix and its limits

**The resident helper holds a press until the switch it started has landed.** It remembers, per app
process (pid and start time), when complete mode is due. An AXPress arriving earlier sleeps until
then, finds its target again — the switch re-sends the whole tree, so an element found before it may
have been replaced — and presses, and its report line gains `full_mode_wait_ms`. Only a press within
about 2s of the helper first reaching a process waits: in practice the first AXPress shortcut after
the app launches, and the first after a helper rebuild, since a restarted server remembers nothing. A
miss answers before the wait, so `--else-key` is never delayed.

**The server starts the countdown at launch, not at the first press.** Waiting at the press put
2.1s on the first Cmd+P or Cmd+Shift+U after every launch, and the Claude app relaunches for each
update: seven launches and five waited presses on 2026-09-24. So the LaunchAgent runs the server at
login with `--prime com.anthropic.claudefordesktop`, and it sets the attribute when that app
launches, when it is activated, and when the server itself starts; a press arriving more than 2.1s
after the launch waits for nothing. A press made while a set of ours is counting down skips its own
set, so it waits out the remainder rather than a fresh 2.1s. The log has one `primed` line per
process. Prime only apps that take the attribute: in any other Electron app the set would turn on
complete accessibility, whose cost that app pays for a press it never gets.

**Complete mode can drop mid-session, and nothing says so before the press.** On 2026-09-24 the
app's log showed basic mode at sets with no relaunch between (06:37:45, 07:27:37), and the presses
behind them logged `pressed=true` without the wait and did nothing; the retry 5s later worked.
Something set the attribute to `false`. Re-priming on every activation brings the mode back 2s after
the user returns to the app, but a press inside that window, or a drop while the app stays
frontmost, still misses. Codex's computer-use client (`SkyComputerUseClient`) was running while the
app's log recorded about 90 sets a minute, none of them the helper's.

**A popup trigger says after the press, so the helper retries a dropped one.** `AXExpanded` on the
Usage button went true 25-31ms after a landed press. So an AXPress on an `AXPopUpButton` whose `AXExpanded`
is `false` polls it for 200ms; still false, the press was dropped, and the request's own set (made at
its start, since none was pending) has started a switch. The helper records that switch as due,
sleeps until it lands, finds the target again and presses once more, and the report line gains
`dropped_retry_ms` (the sleep) and `retry_expanded`. A trigger that did expand is never pressed
again, since a second press closes the popup -- including one that opened during the sleep, which
under load a landed press can (`retry=skipped-expanded`). Only the role says which targets can tell:
Chromium answers `AXExpanded` false on a plain button too, which no press flips, so the task chip's
Start button, pressed and gone, was taken for a drop and pressed again. A plain button's dropped
press still goes unnoticed.

**What it does not cover.** Another client setting the attribute restarts Electron's countdown without
the helper knowing, so a retry timed to the helper's own set can land early and drop again
(`retry_expanded=false`). Nor load: with all eight cores pegged, presses in complete mode did not open the
menu within 3s either, so a probe polling the tree under load measures the load, not the switch.

## Reading the mode

**The Claude app logs its mode at every set.** `~/Library/Logs/Claude/main.log` has
`[a11y] accessibility support enabled|disabled features=...` for each `AXManualAccessibility` or
`AXEnhancedUserInterface` set, reporting the mode at that moment, and `disabled at startup
features=none` at each launch. `features=nativeAPIs,webContents` is basic;
`…,inlineTextBoxes,extendedProperties,screenReader` is complete. The switch itself logs nothing, so a
line dates the mode at the next set, not the change. Older lines rotate into `main1.log` (newest),
`main2.log` and up. The same log's `LocalSessions.archive: sessionId=…` confirms that an archive
landed, without asking the user.

**None of the attributes that look like mode signals are.** `AXDOMClassList` is serialized in basic
mode too (`SerializeElementAttributes`). Electron's `AXManualAccessibility` getter answers whether the
mode *equals* complete, and the screen-reader flag its own setter adds makes that false in both modes.
`AXPress` is in a button's action names whether or not it has the verb, because `IsClickable` falls
back to the role. What does change is the effect: a popup trigger's `AXExpanded` turns true within
about 100ms of a press that landed — which only a press can find out.

## Reproducing the first press after a launch

**Drop the app back to basic mode instead of relaunching it.** Relaunching the Claude app ends the
Claude Code session running inside it. Setting `AXManualAccessibility` to `false` while no switch is
pending (2s or more after the last set) makes Electron drop complete mode at once, and presses after
that were dropped exactly as a fresh launch's were (3 of 3); a `true` brings it back 2s later. System
Events can write it, no helper needed:
`tell application "System Events" to tell process "Claude" to set value of attribute "AXManualAccessibility" to false`.

**The server's priming undoes a drop whenever the app comes to the front.** An activation sets the
attribute, and 2s later presses land again, so a drop made before the user switches back to the app
tests nothing. Drop the mode while they are already in the app, more than 2.1s after the server
started (it primes at start), and ask for one press without switching apps. The pass for the
dropped-press retry is `dropped_retry_ms` with `retry_expanded=true` on the line and the popup
opening about 2s late. A press the user makes during the retry's sleep queues behind it and runs
right after, closing the popup, so ask for exactly one.

**Check the live helper is the build under test before reading a press** — another session's ship
can rebuild it from main at any time ([ax-press-helper.md](ax-press-helper.md) "Building").

**A probe from a Claude desktop session's shell can press, which the helper refuses to do from a
shell.** That shell carries the Claude app's own Accessibility grant (see "Bisect the underlying UI"
in [debugging.md](debugging.md)), so a scratch Swift program can find the trigger, `AXPress` it, poll
`AXExpanded`, and sweep the press time around the switch — no rule, and no human press per trial.
Build it with `DEVELOPER_DIR=/Library/Developer/CommandLineTools` while Xcode's license is unaccepted.

**Opening menus in the app you are running inside needs guards and a hands-off window.** Aim only at
the session on screen (check the header's `"<title>, rename session"` label first), never press a
menu item, and close with Escape only while the trigger reports `AXExpanded` true and focus is not in
a text field: an Escape that reaches the composer interrupts a running turn, and a letter the user
types into the open chat menu activates an item (`a` archives). Ask the user not to type for the
length of the run, and put the mode back (`true`) when a run aborts after dropping it.

## Techniques that transferred

**Read the source at the app's exact versions before probing.** The Electron version is
`CFBundleVersion` in `Contents/Frameworks/Electron Framework.framework/Resources/Info.plist`; the
Chromium version is a `Chrome/<version>` string in the framework binary (match it with Python `re`
over an `mmap`; `strings` is an Xcode shim here). Chromium files come from
`https://chromium.googlesource.com/chromium/src/+/refs/tags/<version>/<path>?format=TEXT` (base64),
Electron's from `https://raw.githubusercontent.com/electron/electron/v<version>/<path>`. Three files
held the whole mechanism: `shell/browser/mac/electron_application.mm`,
`ui/accessibility/platform/browser_accessibility_manager.cc` and
`third_party/blink/renderer/modules/accessibility/ax_object.cc`.

**Sweep the press time across the transition, on both sides of it.** Pressing at fixed offsets after
the set, some before the expected switch and some after, found the cliff in two runs of five presses.
Offsets on one side only would have shown a floor or a ceiling, never the edge.
