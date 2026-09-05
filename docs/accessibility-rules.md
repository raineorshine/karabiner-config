# Accessibility rules

## Accessibility rules (press a control by name)

**This is the first thing to try for any control, not the fallback once coordinates have failed.** A
target that moves with the content is merely where the difference is starkest: the Copy button
under ChatGPT's last response sits wherever the response ends, and the app has no shortcut or menu
item for it (its bindable-shortcut registry was searched). `scripts/ax-press.swift`,
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

**A dump is filtered and it is a snapshot; both mislead quietly.** The query hides every element
whose labels do not contain it, so a row read through one letter looks shorter than it is — a
control was concluded absent this way, and it was there the whole time under a label the query did
not match. Dump a row through more than one query before believing what is not in it. And the app
moves while you work: between two of these dumps the user navigated, and the second was a different
screen with no marker saying so. Say which screen a label came from, and re-dump rather than
reasoning across two dumps taken minutes apart.

**A target that exists for only a few seconds is inspected by polling `--dump` while it is up.** A
toast cannot be dumped on demand, so loop the dump (~1.1s per pass here) and ask for one press that
triggers it. Shortwave's Always apply toast stayed in the tree for 44 consecutive dumps (~45s), wide
enough that the rule needs no `--wait`. Query one letter (`a`) when the wording is unknown and diff
the dumps for what appeared. The empty query is the trap the paragraph above names: a first run of
400 dumps passed `""` and could not have found anything.

**Shortwave (`com.electron.shortwave`) exposes its web content like any Chromium tree**, and labels
its own controls: `AXButton AXTitle="Compose"`, `AXImage AXDescription="Avatar for …"`, and the
Always apply toast's `AXButton AXTitle="Always apply"`. So a target there is worth dumping for before
any coordinate is measured.

**SwiftUI puts a native label in `AXValue`, and the control that acts is often not the labelled
one.** Karabiner-Elements' own settings sidebar is an AXOutline whose rows each hold an AXImage (the
SF Symbol, `AXIdentifier="gearshape"`) and an AXStaticText carrying the section name — in `AXValue`,
so a search over the Chromium-shaped attributes found *nothing at all*, not a wrong element. AXValue
is a label attribute now; it also carries a text field's contents, so pair a label that could be
something typed with a `--role`. The row is what selects, and it has no AXPress: its only actions are
AXShowDefaultUI and AXShowAlternateUI. So `--ancestor AXRow` climbs from the match by AXParent to the
enclosing role, and `--set AXSelected=true` writes an attribute instead of performing an action —
which is what navigates. Ten sections, 14-58 elements, 15-96ms.

**Ask System Events before touching the helper's source.** `osascript` UI scripting is granted here
for reads *and* attribute writes — only synthetic keystrokes are refused (System Events error 1002),
which is easy to mistake for the whole permission being absent. `entire contents of window 1` names
every element by its path, `name of every action of row 2` says what a control can do, `properties
of` dumps its attributes, and `set selected of row 3 to true` *proved* that writing AXSelected
navigates — all before a line of Swift changed. The helper only ever shows you elements labelled the
way it already knows how to look; System Events shows the tree as it is. It is an inspector, not a
rule mechanism: a Karabiner-spawned `osascript`'s permissions are the unpredictable case the next paragraph
describes.

**Accessibility permission goes to the helper itself, which is what makes it predictable.** TCC
judges a command-line tool by whatever launched it — a terminal, or Karabiner — which is why the same
script can post events from one rule and not another. The helper re-spawns itself with
`responsibility_spawnattrs_setdisclaim`, the private posix_spawn attribute Chromium uses for its own
helpers, so the child is judged as the binary wherever it was launched from: granted once in System
Settings, it reported trusted=true from a shell and from Karabiner alike. The grant is keyed to the
binary's ad-hoc signature, so every rebuild needs it granted again — six rebuilds, six regrants in
the session that built it; `scripts/build-ax-press.sh` has the steps, and a self-signed signing
certificate is the fix if that ever becomes routine.

**The binary is shared across worktrees; the source is not.** `scripts/build-ax-press.sh` writes to
the *main* checkout's `scripts/bin/` whichever worktree it runs from, because that is where the
rules point. A build from a branch behind `main` therefore replaces the live binary with one missing
whatever options landed meanwhile, and a rule that passes a dropped option fails as an ordinary
miss — nothing says the option is gone. Rebase before building, or pay a second regrant to rebuild
after the rebase, which is what happened here.

**A rebuild blinds you until the regrant, so learn everything first and build once.** `--dump` and
`--dry-run` report `trusted=false` too, so the tool cannot be used to work out what to build next,
and the user has to remove the stale Accessibility entry and re-approve before anything works again —
including every rule already relying on the helper. The Karabiner-settings work read the tree with
System Events, decided on two new capabilities (`--ancestor`, `--set`) plus AXValue, and spent one
rebuild.

**Regranting means deleting the entry, and the deletion empties the list, so run the helper again.**
Toggling the existing `karabiner-config-ax-press` entry off and on again does not re-request: the
stale signature is still what the entry records. The user removes the row with `-`, which leaves
nothing to toggle — the row comes back only when the binary next asks for Accessibility. So after
the user says the entry is deleted, run the helper once (`--dump` from a shell is enough) to re-add
it, then wait for them to switch the fresh entry on. And do not read the first run's output as the
grant taking effect: that run is what registers the entry, and it reports `trusted=false`.

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

**Direction is not a discriminator, and neither is `--sibling`, when the rivals share a parent.**
`--sibling` asks whether *some* child of the match's parent carries the label, so it selects a whole
row at once rather than a member of it — and if the row's parent also holds unrelated controls, they
are in the set too, which is how a reverse walk aimed at a folder row landed on the usage meter.
When two controls share their role, their parent, and a label that is plain varying text — the
Claude app's folder row puts a local/cloud popup immediately before the project picker — only their
order separates them, and `--nth` takes the nth match in walk order, counted per window. Reach for
it last: an ordinal breaks silently when the app inserts a control ahead of the target, so a label,
a distinct role or a sibling outside the row is worth more when one exists.

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
