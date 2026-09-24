# Accessibility rules (press a control by name)

**This is the first thing to try for any control, not the fallback once coordinates have failed.**
`ax-press` finds a control by role and label in the app's focused window and `AXPress`es it: no
coordinates, no pointer movement, no restore, and the press lands on an element scrolled out of view.
A target that moves with the content is where the difference is starkest: the Copy button under
ChatGPT's last response sits wherever the response ends, and the app has no shortcut or menu item for
it. A rule's `shell_command` sends the arguments to the resident helper:

```
printf '%s\0' <bundle-id> <label> [options] | /usr/bin/nc -U "$HOME/.config/karabiner/scripts/bin/ax-press.sock"
```

A shell runs the binary itself with the same arguments, which is what `--dump` and `--dry-run` are
for. The options are documented at the top of `scripts/ax-press.swift`. The helper's server, build,
signing and Accessibility grant are [ax-press-helper.md](ax-press-helper.md); why a press can log
success and do nothing in an Electron app is [accessibility-modes.md](accessibility-modes.md).

## Finding the label

**Chromium puts aria-labels in `AXDescription`; tooltips are not in the tree at all.** The button the
app's tooltip calls "Copy response" is `AXDescription="Copy"`, and code-block copy buttons carry the
same label, so the rule discriminates by a sibling (`--sibling "Good response"`), not by depth or
frame. `--dump` lists every labelled element with roles and frames; read it before guessing a label,
and query a substring — an empty query matches nothing.

**When the user names a control by its tooltip, search the app's bundle for that text.** An Electron
app's renderer is minified JS in plain text inside `Contents/Resources/app.asar`, and the component
that renders the tooltip names the aria-label beside it: ChatGPT's "Thinking effort" pill is
`AXDescription="Select ChatGPT model"`, which no dump query for "effort" could have found. Its event
handlers sit there too, which is what explains a press that does nothing ("Pressing" below). Search it
with Python `mmap` and `re`: this machine's `grep` is ugrep, which refuses a context pattern such as
`.{0,160}effort.{0,160}` on a file that size ("exceeds complexity limits").

**The Claude desktop app's renderer is not in its `app.asar`.** The Code tab's components and their
`defaultMessage` strings live in `Contents/Resources/ion-dist/assets/v1/*.js`, where a plain `grep -l`
finds the file and the aria-label sits beside the label text (the suggested-task chip's primary
button is `"aria-label": labels.primary`, one of six strings). The running renderer loads its chunks
from `assets-proxy.anthropic.com` (the URLs are in `~/Library/Logs/Claude/claude.ai-web.log` stack
traces), and a chunk's hash there can differ from the bundled one's, so read ion-dist as close to
what runs rather than exactly it.

**SwiftUI puts a native label in `AXValue`, and the control that acts is often not the labelled
one.** Karabiner-Elements' own settings sidebar is an AXOutline whose rows each hold an AXImage (the
SF Symbol, `AXIdentifier="gearshape"`) and an AXStaticText carrying the section name in `AXValue`.
AXValue also carries a text field's contents, so pair a label that could be something typed with a
`--role`. The row is what selects, and it has no AXPress: its only actions are AXShowDefaultUI and
AXShowAlternateUI. So `--ancestor AXRow` climbs from the match by AXParent to the enclosing role, and
`--set AXSelected=true` writes an attribute instead of performing an action — which is what
navigates. Ten sections, 14-58 elements, 15-96ms.

**Ask System Events before touching the helper's source.** `osascript` UI scripting reads the tree
and writes attributes: `entire contents of window 1` names every element by its path, `name of every
action of row 2` says what a control can do, `properties of` dumps its attributes, and `set selected
of row 3 to true` *proved* that writing AXSelected navigates — all before a line of Swift changed.
The helper only shows elements labelled the way it already knows how to look; System Events shows the
tree as it is. It is an inspector, not a rule mechanism: a Karabiner-spawned `osascript`'s permissions
are unpredictable ([click-rules.md](click-rules.md)). Synthetic keystrokes through it need the shell
to hold Accessibility itself, which a Claude desktop session's shell does (System Events error 1002
otherwise; see "Bisect the underlying UI" in [debugging.md](debugging.md)).

**Except on some Chromium and Electron apps, where System Events sees nothing at all.** It answered
`count of windows` with 0 for a running Shortwave with a window on screen, and still answered 0
right after `ax-press` had walked that same window. There the helper is the only inspector, which is
what `--dump-all` and `--actions` are for: a label query cannot show a container, because a container
is precisely an element with no label to query. The Claude app, with its accessibility already on,
was the opposite: System Events listed its window and whole web tree (seconds per walk) and wrote
`AXManualAccessibility` on it.

**The tree does not say which item is current when the app keeps that in `data-*` attributes.** The
Claude app's sidebar rows are identical to accessibility: `AXSelected` 0, `AXARIACurrent` empty, and
`AXDOMClassList` (Chromium exposes the class attribute, and `AXDOMIdentifier` the id) the same
Tailwind variant list on every row, because the state lives in a `data-selected` attribute nothing
exposes. What did name the current chat was another labelled element: the header's `"<chat>, rename
session"` button. `--label-from "{}, rename session"` reads it and fills the `{}` in the target label
(`"More options for {}"`). When the target is "the current X", look for a label elsewhere on the page
that spells X out.

## Reading dumps

**A dump is filtered and it is a snapshot; both mislead quietly.** The query hides every element
whose labels do not contain it, so a row read through one letter looks shorter than it is — a control
was concluded absent this way, and it was there under a label the query did not match. Dump a row
through more than one query before believing what is not in it. The app also moves while you work:
between two dumps the user navigated, and the second was a different screen with no marker saying
so. And a dump only describes the state it was taken in: an inbox short enough to fit the window
showed neither the clipped frames nor the virtualised list the Shortwave last-email rule turns on.
Ask for the state that exercises the rule before designing against a dump, say which screen a label
came from, and re-dump rather than reasoning across two dumps taken minutes apart.

**A target that exists for only a few seconds is inspected by polling `--dump` while it is up.** Loop
the dump (~1.1s per pass) and ask for one press that triggers it. Shortwave's Always apply toast
stayed in the tree for 44 consecutive dumps (~45s), wide enough that the rule needs no `--wait`. Query
one letter (`a`) when the wording is unknown and diff the dumps for what appeared; a first run of 400
dumps passed `""` and could not have found anything.

**A screen the agent cannot reach is inspected by a watcher the user walks onto.** The helper refuses
to press from a shell, so a screen that needs navigating is only readable once someone else is on it.
The Claude app's New Session screen exists only while the user has it open, so a background loop of
`--dump-all` saved each dump that matched a marker of that screen (a control only it has) while the
user navigated there — and a second loop, keyed on the marker disappearing, caught the other state of
the same control after they toggled it. Key the marker on something only the wanted screen carries: a
first loop keyed on an absence also fired on an ordinary session view. Run competing `--dry-run`s in
the same loop iteration, so two selectors are compared against the same tree.

**A target the session can put up itself needs no visit.** The suggested-task chip is rendered by a
`spawn_task` call from the session on screen, so the agent building a rule for it can raise one, poll
`--dump` until the label appears, and `dismiss_task` afterwards — the user only has to be looking at
that session. Ask for a visit only for state the tools cannot produce.

**A modal empties the tree behind it.** Shortwave's settings dialog left 65 elements where the mail
view had about a thousand: Chromium exposes the dialog and marks the page behind it inert, so a search
inside a dialog needs no `--within` or `--under`, and a search for anything behind it finds nothing
while it is up. A label is shown to be unique the same way: the dialog's Save button cannot collide
with a page it cannot see, so the question is whether the view underneath carries the label once the
dialog is gone.

**A virtualised list holds the rows it has drawn, not the list.** Shortwave's thread list exposed 33
row groups of a mailbox with far more, and the rows past the bottom of the window carry frames clipped
to zero height at the window's edge. So the last row in the *tree* is not the last row in the *list*:
`--scroll-to-end` AXScrollToVisibles the last match, looks again, and repeats until the last match
stops changing. Two rounds settled it, 166-261ms all in. The comparison is the whole `describe` line,
labels and frame together, because two adjacent rows can share an avatar.

## Telling rivals apart

**The same word in a different attribute is a different control, and `--label-attr` says which.**
The Claude app's New Session environment pill is `AXPopUpButton AXTitle="Cloud"`, its visible text;
a cloud session's header opens with an icon-only popup `AXDescription="Cloud"`, its aria-label. Both
rows also hold an "Add repository" trigger (hidden in the header), so `--sibling` cannot separate
them; `--label-attr AXTitle` does. A reply ends `exit=<code>`, which is how one `shell_command` tries
a second label only when the first missed (`case ... in *exit=4*)`): `--then` runs on success, not on
a miss.

**A label that repeats outside the region that matters is what `--within` is for.** Every Shortwave
row carries an `AXImage AXDescription="Avatar for <sender>"`, but the account avatar in the toolbar
and the avatars inside an open thread carry the same wording. Rows sit in the list column at x≈55,
the thread's at x≈722, the account's at (1440,67), so `--within 40,100,300,1200` keeps the search to
the column. The rectangle is in screen coordinates and so moves with the window.

**The element that presses may be an unlabelled ancestor; count the climb.** Only some elements in
the chain above a Shortwave avatar answer AXPress — the avatar's own wrapper does (it toggles
selection), and so does the row container six levels up — so the climb is counted rather than aimed
at a role: `--ancestor '*:6'`, where `*` counts every level. `--dump-all --actions` is what shows
this; a filtered dump hides every container.

**Pick the walk direction from where the target sits.** The default walk is reverse pre-order —
children last to first, then the node — so it returns the last match in document order after
visiting the composer and the last turn rather than the whole conversation. That is right for a
button under the last response (if the newest turn is a user message or still streaming, the
previous response's button is the last one; the rule's comment says so). For a sidebar at the
*start* of the document it would cross the whole transcript first; `--first` reached the Claude app's
row after 497 elements, 57-78ms. `--dump` walks *forward*, so its numbering is document order and the
default search returns the *last* match listed — read the dump that way round before choosing. Order
is also a discriminator on its own when the rivals sit at opposite ends: Shortwave's toolbar Compose
button and the Settings sidebar's Compose row share a label, and the default walk finds the sidebar
row.

**`--sibling` sees through wrappers.** An unlabelled AXGroup holding one child is not counted as a
level on either side: the match climbs out of its wrappers to find its row, and each child of the row
is read through its own. ChatGPT began wrapping each composer control in such a group, and with plain
parent-and-children semantics the Cmd+Shift+F rule logged `found=false` with nothing else wrong. A
rule that goes quiet after an app update is worth a `--dump-all` around the qualifier first.

**Direction is not a discriminator, and neither is `--sibling`, when the rivals share a parent.**
`--sibling` asks whether *some* child of the match's parent carries the label, so it selects a whole
row at once — and if the row's parent also holds unrelated controls, they are in the set too, which
is how a reverse walk aimed at a folder row landed on the usage meter. When two controls share their
role, their parent, and a label that is plain varying text — the Claude app's folder row puts a
local/cloud popup immediately before the project picker — only their order separates them, and
`--nth` takes the nth match in walk order, counted per window. Reach for it last: an ordinal breaks
silently when the app inserts a control ahead of the target.

**A qualifier has to be in the row in every state the screen has.** A control the app renders only
once something is chosen — the folder row's add-another-folder button appears with a folder and not
without one — qualifies the row in the state you dumped and empties the match set in the other, and
the rule then does nothing. Prefer a sibling the row always carries, even one whose label is a mode,
and say in the comment which mode it assumes. `found=false` in `.claude/ax-press.log` is what this
looks like after the fact.

**When the target's label changes with the screen, qualify the row and wildcard the label.**
ChatGPT's composer picker is `AXDescription="Select ChatGPT model"` in Chat mode and an `AXTitle`
naming the model in Work mode; `"{}" --role AXPopUpButton --sibling "Add files and more"` finds it in
both, because the attach button is in that row on every screen. The wildcard lets in every popup in
the row, so the walk direction decides between them — Work mode's permissions popup comes first —
with the same fragility as `--nth`.

## Pressing

**`pressed=true` says the accessibility call succeeded, not that the control did anything.**
ChatGPT's effort pill logged it on every press and never opened. Its trigger opens on a real
pointer-down, or on a `click` whose `detail` is 0, and Chromium's accessibility press is neither. The
Claude app's popup buttons do open on AXPress, so this is per control, not per framework. When the log
says pressed and the screen says nothing, first rule out an Electron app whose complete accessibility
mode is not on — the helper waits for it after a launch and retries a dropped popup-button press, but
a plain button's dropped press, or a mode another client switched off, still gets through
([accessibility-modes.md](accessibility-modes.md)). Otherwise read the trigger's handlers in the
bundle and move to `--click` ([click-rules.md](click-rules.md)).

**Read the trigger's wrapper before spending a press on AXPress.** ChatGPT's profile button hands
itself to a dropdown component as `triggerButton`, the same shape as the effort pill, so its
Cmd+Shift+U rule went to `--click` from the start and worked on the first press. A click is also a
toggle for free: a dropdown treats a second click on its own trigger as a press outside its content
and closes, which AXPress, dispatching no pointerdown, cannot do.

**A clipboard write needs the document focused.** AXPress reports success either way, but the page's
clipboard write is refused when the window is not frontmost, and ChatGPT shows a "couldn't copy"
toast. A shell test with another app in front does not test the copy.

**Sequencing anything after a helper call is the helper's job.** Karabiner cannot wait on a
`shell_command`, so a key_code after one is only ever a fixed hold behind a spawn. Commands joined
with `--then` in one request sequence themselves, each running only if the one before exited 0
(`&&` cannot, because `nc` exits 0 whatever the server answered), and `--wait` lets the second poll for
a control the first is still bringing on screen (the Archive item of a dropdown, found 16-31ms in). A
trailing key chord goes through `--key`, which the helper posts as a CGEvent once the pressed control
has left the tree — the menu closing is the click having been handled, 118-580ms after the press in
the Claude app.

**Waiting only helps when the target outlives the wait.** Archiving a chat took its project's whole
sidebar group away, + button included, so no sequencing behind the app's own navigation could reach
it and the press had to happen before the archive instead. Ask what the tree looks like after the
first press before reaching for `--wait`, and reorder when the second target no longer exists.

## Sharing a chord with the app

**Karabiner's conditions see the frontmost app and nothing inside it**, so a shortcut that should
only apply on one *screen* of an app cannot be scoped by the rule — the helper's own hit or miss is
the only thing that knows, and the key has to survive being bound on every other screen.

**For a command chord, `--else-key` hands it back.** It posts the chord when nothing was found, so
the rule presses the control on the one screen that has it and every other screen gets the key it
would have got: Shortwave's Cmd+Enter sends mail everywhere except its settings dialogs, where Save
has no shortcut at all. A miss in a populated tree ends on the first pass rather than spending
`--budget-ms`, and Karabiner does not see the posted chord (a CGEvent is posted below its IOKit grab),
so a rule can post the very chord that fired it. The cost moves onto the *common* path: every send
pays a request plus a full walk, and `--log` writes a line for each. It works only for a chord the
app treats as a command: bound to character keys, every letter reported `else_key_posted=true` and
not one reached the focused input.

**A rule bound to a key you also type emits the key itself rather than handing it back.** Shift plus
a letter counts: Shortwave's Shift+G swallowed every capital G typed in a reply until it took this
shape. `to` takes a `key_code` and a `shell_command` together, so Karabiner types the character and
the helper runs behind it: nothing is swallowed, nothing waits on a launch, and the app's own
single-key shortcuts still fire. `--unless-editing` makes the press stand down: it reads the app's
`AXFocusedUIElement` and does nothing while that is a text control. Without it, Shortwave's settings
sidebar jumped on every letter typed into a label picker's search box. The read comes before any
walk, so typing is the cheap path. Leave `--log` off such a rule: nothing rotates that file.

## Verifying a rule

**An agent cannot fire the rule, so it checks each half.** The helper refuses presses from a shell
([ax-press-helper.md](ax-press-helper.md)), and keys a computer-use tool posts never reach
Karabiner. `--dry-run` the search on every screen the rule must work on, perform the action with a
computer-use click on the frame it reports, and `--dry-run` the `--then` step against what that click
put up. The keypress itself is then the user's.

**`--dry-run` from a shell verifies the target before the lock is taken.** It resolves `--label-from`
and finds the element without pressing, so the live-config lock is held only for the presses
themselves (110ms, `label="More options for 💰 TSLA exit strategy"`).

**A backgrounded app answers `AXFocusedUIElement` with nothing.** A one-off `--dry-run` from a shell
cannot check anything conditioned on focus; it reports `focused=none`. A dry run *polled in the
background* while the user drives the app can, because the app is frontmost then: ChatGPT's poll read
`editing=AXTextArea` turning into `focused=AXMenuItem` across a press. That is how to learn where focus
lands without a rule; the rule itself, with `--log` on, is the other way.

## Chromium and Electron trees

**Chromium exposes none of the page until an assistive client shows up, and what counts as showing
up is asking the *application object* for its role.** A freshly launched ChatGPT — and Brave — answers
with the window chrome only: 12 elements, no `AXWebArea`, and no amount of walking windows, reading
labels, hit-testing, focusing the window or clicking into it changes that. Chrome's and Electron's
NSApplication subclasses both switch accessibility on in `accessibilityRole`, so one `AXRole` read of
the application element is the switch: an instance that had ignored everything else exposed its tree
124ms after it. The helper does this first thing. The switches a client used to set are dead in
ChatGPT *and* Brave — Electron's `AXManualAccessibility` is unsupported (-25205),
`AXEnhancedUserInterface` returns not-implemented (-25208), and Chromium 151 no longer watches it —
but the Claude desktop app still accepts `AXManualAccessibility`, and that set is what brings, 2s
later, the complete mode an AXPress needs. Exposing the tree and acting on a press are separate
thresholds ([accessibility-modes.md](accessibility-modes.md)). `--force-renderer-accessibility` on
the command line also works. Read the source before another round of probing: the answer was one
fetch of `chrome_browser_application_mac.mm` away, after five rebuilds spent guessing. Untested:
Chromium can drop accessibility for a web contents hidden for five minutes or more
(`AccessibilityDisabler`), so a press that logs `tree_exposed=false` after the window sat behind
others is the first thing to suspect.

**A second instance of ChatGPT is a clean process to experiment on.** Launching the binary directly
with its own `--user-data-dir` and `CODEX_ELECTRON_USER_DATA_PATH` sidesteps the process singleton,
so the user's running instance and its Codex sessions are untouched. It signs into the same account,
so delete the scratch profile afterwards.

## App notes

**Shortwave (`com.electron.shortwave`) exposes its web content like any Chromium tree**, and labels
its own controls: `AXButton AXTitle="Compose"`, `AXImage AXDescription="Avatar for …"`, and the Always
apply toast's `AXButton AXTitle="Always apply"`. Dump there before measuring any coordinate.

**Claude desktop app, Code tab** (inspected on 1.40609.0). The sidebar is an `AXGroup` (subrole
`AXLandmarkComplementary`, description `Sidebar`). Each chat row is an `AXButton` titled `"<status>
<title>"` (`Idle`, `Running`, `Awaiting input`), with an `AXPopUpButton` described `"More options for
<title>"` beside it — hover-revealed (`opacity-0`, `pointer-events-none`) yet present in the tree, and
`AXShowMenu` on it opened the row's menu. The session header carries an `AXButton` described
`"<title>, rename session"` and, at the top right of the main pane, an `AXPopUpButton` described
`"More options for <title>"` — the **same label as the sidebar row's button**, so a `--first` search
finds the row while the sidebar is visible and the header button once it is hidden. `AXShowMenu` on
the header button gets Electron's default Copy/Select All menu; `AXPress` on it opens the chat's
dropdown (Archive and the rest) with no sidebar needed, which the Cmd+Shift+E archive rule uses.
Titles may begin with an emoji, and they are **not unique** across projects; the header's
`AXPopUpButton` titled with the project's name says which project the current chat is in. The Chat
tab's header was not inspected. The suggested-task chip (top right of the transcript) is a split
button: an `AXGroup` *described* with the primary label wraps an `AXButton` *titled* with it and an
`AXPopUpButton` described `"More start options"`, so a search for the label without `--role AXButton`
can land on the group. The label is whichever start target the app chose (`Start with worktree`,
`Start locally`, `Send to cloud`, ...), so the popup is the stable handle.

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
