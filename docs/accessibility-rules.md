# Accessibility rules

## Accessibility rules (press a control by name)

**This is the first thing to try for any control, not the fallback once coordinates have failed.** A
target that moves with the content is merely where the difference is starkest: the Copy button
under ChatGPT's last response sits wherever the response ends, and the app has no shortcut or menu
item for it (its bindable-shortcut registry was searched). `scripts/ax-press.swift`,
built as `scripts/bin/karabiner-config-ax-press`, finds a control by role and label in the app's
focused window and `AXPress`es it: no coordinates, no pointer movement, no restore, and the press
lands on an element scrolled out of view. A rule does not launch it. Its `shell_command` sends the
arguments to the resident helper — `printf '%s\0' <bundle-id> <label> [options] | /usr/bin/nc -U
"$HOME/.config/karabiner/scripts/bin/ax-press.sock"` (see "The helper is a resident server" below) —
while a shell runs the binary itself with the same arguments, which is what `--dump` and `--dry-run`
are for. Some rules perform AXShowMenu rather than AXPress — see "Context menus".

**Chromium puts aria-labels in `AXDescription`; tooltips are not in the tree at all.** The button the
app's tooltip calls "Copy response" is `AXDescription="Copy"`, and code-block copy buttons carry the
same label, so the rule discriminates by a sibling (`--sibling "Good response"`), not by depth or
frame. `--dump` lists every labelled element with roles and frames; read it before guessing a label,
and query a substring — an empty query matches nothing.

**When the user names a control by its tooltip, search the app's bundle for that text.** An Electron
app's renderer is minified JS in plain text inside `Contents/Resources/app.asar`, and the component
that renders the tooltip names the aria-label beside it: ChatGPT's "Thinking effort" pill is
`AXDescription="Select ChatGPT model"`, which no dump query for "effort" could have found. Its event
handlers sit there too, which is what explains a press that does nothing (next paragraph). Search it
with Python `mmap` and `re`: this machine's `grep` is ugrep, which refuses a context pattern such as
`.{0,160}effort.{0,160}` on a file that size ("exceeds complexity limits").
The Claude desktop app's renderer is not in its `app.asar` at all: the Code tab's components and
their `defaultMessage` strings live in `Contents/Resources/ion-dist/assets/v1/*.js`, where a plain
`grep -l` finds the file and the aria-label sits beside the label text (the suggested-task chip's
primary button is `"aria-label": labels.primary`, one of six strings). Its in-app shortcuts are
literal `cmd+shift+<x>` strings in the same files, which is how to check a chord before binding it.
That copy ships inside the app, but the running renderer loads its chunks from
`assets-proxy.anthropic.com` (the URLs are in `~/Library/Logs/Claude/claude.ai-web.log` stack
traces), and a chunk's hash there can differ from the bundled one's, so read ion-dist as close to
what runs rather than as exactly it.

**`pressed=true` says the accessibility call succeeded, not that the control did anything.**
ChatGPT's effort pill logged it on every press and never opened. Its trigger opens on a real
pointer-down, or on a `click` whose `detail` is 0 (what the app's own shortcut sends through
`element.click()`), and Chromium's accessibility press is evidently neither. The Claude app's popup
buttons do open on AXPress, so this is per control, not per framework. When the log says pressed and
the screen says nothing, read the trigger's handlers in the bundle and move to `--click`
([click-rules.md](click-rules.md)). But first rule out the cause that comes before any handler: in an
Electron app whose complete accessibility mode is not on yet, Chromium drops every AXPress and still
reports success, which is a press that fails right after the app launches and works on the next try
([accessibility-modes.md](accessibility-modes.md)).

**Read the trigger's wrapper before spending a press on AXPress.** ChatGPT's profile button hands
itself to a dropdown component as `triggerButton`, the same shape as the effort pill that AXPress
could not open, so the Cmd+Shift+U rule went to `--click` from the start and worked on the first
press. And a click is a toggle for free: a dropdown treats a second click on its own trigger as a
press outside its content and closes, which AXPress, dispatching no pointerdown, cannot do.

**A dump is filtered and it is a snapshot; both mislead quietly.** The query hides every element
whose labels do not contain it, so a row read through one letter looks shorter than it is — a
control was concluded absent this way, and it was there the whole time under a label the query did
not match. Dump a row through more than one query before believing what is not in it. And the app
moves while you work: between two of these dumps the user navigated, and the second was a different
screen with no marker saying so. And a dump only ever describes the state it was taken in: an inbox
short enough to fit the window showed neither the clipped frames nor the virtualised list that the
Shortwave last-email rule turns on, both of which appeared the moment the same view was long enough
to scroll. Ask for the state that exercises the rule before designing against a dump. Say which
screen a label came from, and re-dump rather than
reasoning across two dumps taken minutes apart.

**A target that exists for only a few seconds is inspected by polling `--dump` while it is up.** A
toast cannot be dumped on demand, so loop the dump (~1.1s per pass here) and ask for one press that
triggers it. Shortwave's Always apply toast stayed in the tree for 44 consecutive dumps (~45s), wide
enough that the rule needs no `--wait`. Query one letter (`a`) when the wording is unknown and diff
the dumps for what appeared. The empty query is the trap the paragraph above names: a first run of
400 dumps passed `""` and could not have found anything.

**A screen the agent cannot reach is inspected the same way, by a watcher the user walks onto.** The
Claude app's New Session screen exists only while the user has it open, in the window they are
using, so a background loop of `--dump-all` saved each dump that matched a marker of that screen (a
control only it has) while the user navigated there — and a second loop, keyed on the marker
disappearing, caught the other state of the same control after they toggled it. Key the marker on
something only the wanted screen carries: a first loop keyed on an absence also fired on an ordinary
session view.

**Shortwave (`com.electron.shortwave`) exposes its web content like any Chromium tree**, and labels
its own controls: `AXButton AXTitle="Compose"`, `AXImage AXDescription="Avatar for …"`, and the
Always apply toast's `AXButton AXTitle="Always apply"`. So a target there is worth dumping for before
any coordinate is measured.

**A modal empties the tree behind it.** Shortwave's settings dialog left 65 elements where the mail
view had about a thousand: Chromium exposes the dialog and marks the page behind it inert, so a
search inside a dialog is cheap and needs no `--within` or `--under` to keep it off the page — and a
search for anything behind the dialog finds nothing at all while it is up. The two states are
therefore two separate dumps, which is also how a label is shown to be unique: the dialog's Save
button cannot collide with a page it cannot see at the same time, so the question is whether the
view underneath carries the label once the dialog is gone.

**A virtualised list holds the rows it has drawn, not the list.** Shortwave's thread list exposed 33
row groups of a mailbox with far more — a screenful plus a little — and the rows past the bottom of
the window carry frames clipped to zero height at the window's edge, which is Chromium reporting
bounds clipped to the scrollport rather than the row being absent. So the last row in the *tree* is
not the last row in the *list*, and reaching the end means scrolling: `--scroll-to-end` AXScrollToVisibles
the last match, looks again, and repeats until the last match stops changing. Two rounds settled it,
166-261ms all in. The comparison is the whole `describe` line, labels and frame together, because two
adjacent rows can share an avatar.

**The same word in a different attribute is a different control, and `--label-attr` says which.**
The Claude app's New Session environment pill is `AXPopUpButton AXTitle="Cloud"`, its visible text;
a cloud session's header opens with an icon-only popup `AXDescription="Cloud"`, its aria-label. Both
rows also hold an "Add repository" trigger (hidden in the header), so `--sibling` cannot separate
them. `--label-attr AXTitle` matches the label in that one attribute and does. A result reply ends
`exit=<code>`, which is how one `shell_command` tries a second label only when the first missed
(`case ... in *exit=4*)`): `--then` runs on success, not on a miss.

**A label that repeats outside the region that matters is what `--within` is for.** Every Shortwave
row carries an `AXImage AXDescription="Avatar for <sender>"` — the only label the rows share, and so
the only generic handle on a row — but the account avatar in the toolbar and the avatars inside an
open thread carry the same wording. They differ by where they are: rows sit in the list column at
x≈55, the thread's at x≈722, the account's at (1440,67). `--within 40,100,300,1200` keeps the search
to the column. The rectangle is in screen coordinates and so moves with the window, which is the cost
of it; nothing in that tree names the list.

**The row that presses is an unlabelled AXGroup six levels above the avatar.** Only some elements in
the chain answer AXPress — the avatar's own wrapper does (it toggles selection), and so does the row
container at depth 19 — so the climb has to be counted rather than aimed at a role: `--ancestor '*:6'`,
where `*` counts every level. `--dump-all --actions` is what shows this; a filtered dump hides every
container, because containers are exactly the elements with no label to filter on.

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

**Except on some Chromium and Electron apps, where System Events sees nothing at all.** It answered
`count of windows` with 0 for a running Shortwave with a window on screen, and still answered 0
right after `ax-press` had walked that same window. There the helper is the only inspector, which is
what `--dump-all` and `--actions` are for: a label query cannot show you a container, because a
container is precisely an element with no label to query. The Claude app, with its accessibility
already on, was the opposite: System Events listed its window and whole web tree (`entire contents`
with each element's description, seconds per walk) and wrote `AXManualAccessibility` on it.

**Accessibility permission goes to the helper itself, which is what makes it predictable.** TCC
judges a command-line tool by whatever launched it — a terminal, or Karabiner — which is why the same
script can post events from one rule and not another. The helper re-spawns itself with
`responsibility_spawnattrs_setdisclaim`, the private posix_spawn attribute Chromium uses for its own
helpers, so the child is judged as the binary wherever it was launched from: granted once in System
Settings, it reported trusted=true from a shell and from Karabiner alike. The resident server needs no
disclaim: launchd starts it, and a process launchd starts is its own responsible process.

**TCC keys the grant to the binary's path and its designated requirement, so how the binary is signed
decides what the grant survives.** An ad-hoc signature — what the linker leaves — carries an implicit
requirement that pins the code hash, which changes with every compile: six regrants in the session
that built the helper, and one more months later, when a rebuild from *unchanged* source took every
ax-press rule down at once and read as a Claude app update having broken the two of them anyone had
pressed. A self-signed certificate fixed that (`identifier "…" and certificate leaf = H"…"`) and
brought the cost in the next paragraph with it. `scripts/build-ax-press.sh` now signs ad-hoc with an
*explicit* requirement, `designated => identifier "com.raine.karabiner-config-ax-press"`, and TCC stores
exactly that with the grant — tccd logs `CodeReq: identifier "com.raine.karabiner-config-ax-press"` as
it writes the row. Only changing that identifier, or where the binary lives, costs a regrant now. The
certificate protected little: its key was on `codesign`'s access list with Always Allow, so anything
running as the user that could write the binary could sign as it too. Read `~/projects/axshot`'s
`docs/permissions.md` before designing anything else against TCC here; it has usually been solved
there already.

**A certificate amfid cannot chain to Apple costs a daemon launch on every cold start.** amfid turned
the self-signed build down ("adhoc signed or signed by an unknown certificate chain") only after asking
`taskgated-helper` for a provisioning profile, and launchd starts that helper on demand: 62-111ms when
it is not already running, 4ms when it is. The binary runs either way. An ad-hoc signature, with an
explicit requirement or without, leaves amfid in 1ms and asks nothing. The kernel keeps amfid's answer
for the file, but it lapsed after about half an hour idle, so every press after a gap that long paid
the lookup again — which is when presses are already at their slowest (below).

**Rebuilding unchanged source is not a test of that.** `swiftc` is deterministic here and re-emits a
byte-identical binary, so the code hash never moves and the grant is never asked to survive
anything. Move the hash before reading a rebuild as evidence: an `-Onone` build moved it, and the
grant held for the server and a one-shot run alike, which is the claim.

**The binary is shared across worktrees; the source is not.** `scripts/build-ax-press.sh` writes to
the *main* checkout's `scripts/bin/` whichever worktree it runs from, because that is where the
rules point, and restarts the LaunchAgent so the server runs what was just built. A build from a
branch behind `main` therefore replaces the live binary with one missing whatever options landed
meanwhile, and a rule that passes a dropped option fails as an ordinary miss — nothing says the option
is gone. One from a branch older than the resident helper is worse: its binary has no `--serve`, so
every rule fails, and its script signs with the old certificate, so the grant goes too. Rebase before
building, and build again after shipping: the binary a test installed predates the ship's rebase,
so anything that landed on `main` in between is missing from the live helper until the next build.

**The live helper is under the test lock too.** A build swaps the binary and restarts the server,
so one run while another session is testing changes the code that session's presses go through,
and nothing in its test says so: a post-ship rebuild did exactly that to a session mid-test on the
helper, whose result then described a binary it had never built. `scripts/build-ax-press.sh`
therefore refuses while `scripts/karabiner-test-lock.sh` is held by another worktree, and lets the
holder's own builds through. A refused post-ship rebuild is deferred, not dropped: check `status`
again before the session ends and build once it reads `unlocked`, and if it never does, name the
pending rebuild in the report with the command, since the live helper lacks what just shipped until
someone runs it.

**The Xcode tools can refuse to run at all.** `swiftc`, `otool` and every other `xcrun`
shim exit with "You have not agreed to the Xcode license agreements" while the selected Xcode's
license is unaccepted, which is the state after an Xcode update. The build falls back to the Command
Line Tools' own `swiftc`; a probe run by hand needs `DEVELOPER_DIR=/Library/Developer/CommandLineTools`
the same way (or `/Library/Developer/CommandLineTools/usr/bin/llvm-otool` for `otool`).

**Without the grant the helper cannot even look.** `--dump` and `--dry-run` report
`trusted=false` too, so it cannot be used to work out what to build next, and every rule relying on
it is down until the entry is re-approved. Read the tree with System Events instead while that is
true, on an app System Events can see — the Karabiner-settings work did, decided on two new capabilities (`--ancestor`, `--set`) plus
AXValue, and spent one rebuild. The advice this replaces was to learn everything first and build
once; with a stable requirement that is no longer the tradeoff, and only a grant that is actually
missing blinds you.

**Regranting means deleting the entry, and the deletion empties the list, so run the helper again.**
Toggling the existing `karabiner-config-ax-press` entry off and on again does not re-request: the
stale requirement is still what the entry records. The user removes the row with `-`, which leaves
nothing to toggle — the row comes back only when the binary next asks for Accessibility. A dry run
sent every two seconds brings it back the moment it is deleted, so the user can switch the fresh
entry on in the same visit, and the loop ending on `exit=0` is the grant taking effect. Every request
before that answers `trusted=false`, and the server exits after it: a process reads trust once, so a
server that had started without the grant would refuse every press until restarted.

**A copy of the helper at another path is a stranger to TCC, and asking makes it a row.** The
grant belongs to the path, so a copy asks as a new client: it answered `trusted=false`, and the
question alone added a switched-off row for the copy's path to the Accessibility list — two rows,
from two copies, that only the user can delete. Probe a copy's signing or launch cost through the
no-argument usage path, which exits before any accessibility call.

**A helper that carries its own grant is a confused deputy, so it presses only for Karabiner.** The
disclaim hands the binary's Accessibility to whatever runs it, and the server answers anyone who can
reach its socket, which would let any process running as the user press any labelled control in any
app with no interaction — where abusing Karabiner's own input injection at least needs a rule written
into `karabiner.json` and a keypress to fire it. So the helper refuses to press unless Karabiner's
`Karabiner-Console-User-Server` is among the ancestors of whoever asked (checked by full path, under
root-owned `/Library`, not by name): its own for a one-shot run, and for a served request the process
on the far end of the socket, which the kernel names (`LOCAL_PEERPID`) — the `nc` a rule runs, under
Karabiner's `sh`. A press sent from a shell comes back `refused=not-launched-by-karabiner
ancestors=nc<zsh<…`. The helper logs to one fixed file under `.claude/` rather than a path from its
arguments, and leaves `--dump` and `--dry-run` usable from a shell, since reading labels is the modest
end of what it can do. Testing a real press therefore always goes through the rule, and an agent
cannot fire the rule for itself: keys a computer-use tool posts are CGEvents, downstream of the HID
grab where Karabiner reads the keyboard, so no rule ever sees them. What an agent can check is each
half: `--dry-run` the search on every screen the rule must work on, perform the action with a
computer-use click on the frame it reports, and `--dry-run` the `--then` step against what that
click put up. The keypress itself is then the user's. Name the binary so
the Accessibility list says whose it is (`karabiner-config-ax-press`, not `ax-press`), and make the tool
take everything as arguments so a new rule never needs a rebuild. A new *label* never does; a new
*capability* does — `--action` and `--label-from` were one, `--wait` and `--key` another. Each of
those cost a regrant before the requirement was stable; they now cost a build, and an option general
enough that the rule after it is arguments again is still the cheaper shape.

**Sequencing anything after a helper call is the helper's job.** Karabiner cannot wait on a
`shell_command`, so a key_code after one is only ever a fixed hold behind a spawn — the race the helper
was brought in to remove. Commands joined with `--then` in one request sequence themselves, each
running only if the one before exited 0 — `&&` cannot, because `nc` exits 0 whatever the server
answered — and `--wait` lets the second poll for a control the first is still bringing on screen (the
Archive item of a dropdown, found 16-31ms in). A trailing key chord goes through `--key`, which the helper posts as a
CGEvent (its Accessibility grant covers posting) once the pressed control has left the tree — the menu
closing is the click having been handled, 118-580ms after the press in the Claude app.

**But waiting only helps when the target outlives the wait.** A press that mutates a list makes the
app react, and the control you meant to press next can be *gone* rather than merely late: archiving a
chat took its project's whole sidebar group away, + button included, so no amount of sequencing
behind the app's own navigation could reach it and the press had to happen before the archive
instead. Ask what the tree looks like after the first press before reaching for `--wait`, and reorder
when the answer is that the second target no longer exists.

**A shortcut the app already uses can still be bound, because the helper can hand it back.**
`--else-key` posts the chord when nothing was found, so the rule presses the control on the one
screen that has it and every other screen gets the key it would have got: Shortwave's Cmd+Enter
sends mail everywhere except its settings dialogs, where Save has no shortcut at all. Two things
make it sound. A miss in a populated tree ends on the first pass rather than spending the budget —
the retry loop persists only while the tree is too small to be real — so the fall-through costs one
walk, not `--budget-ms`. And Karabiner does not see the posted chord: it grabs the physical device
at the IOKit level and a CGEvent is posted below that, so a rule can post the very chord that fired
it without re-entering itself. What it does move is the cost onto the *common* path — every send
now pays a request to the helper plus a full walk, and `--log` writes a line for each one.
It carries a chord the app treats as a *command*, and only that: bound to keys that are also
characters, every letter reported `else_key_posted=true` and not one of them reached the focused
input, so the key was swallowed outright. A typing key wants the shape below instead.

**Karabiner's conditions see the frontmost app and nothing inside it**, so a shortcut that should
only apply on one *screen* of an app cannot be scoped by the rule — the helper's own hit or miss is
the only thing that knows, and the key therefore has to survive being bound on every other screen.

**A rule bound to a key you also type should emit the key itself rather than hand it back.** Shift
plus a letter counts: it is a capital, and Shortwave's Shift+G swallowed every capital G typed in a
reply until it took this shape. `to`
takes a `key_code` and a `shell_command` together, so Karabiner types the character and the helper
runs behind it: nothing can be swallowed, nothing waits on a process launch, and the app's own
single-key shortcuts still fire. Knowing when to stand down then belongs to the press, which is
`--unless-editing` — it reads the app's `AXFocusedUIElement` and does nothing while that is a text
control. A label is in the tree whether or not the key meant it: Shortwave's settings sidebar rows
match just as readily from inside a label picker's search box as from the sidebar, so without the
check every letter typed there also jumped the sidebar. The read costs one attribute and comes
before any walk, so typing is the cheap path rather than the expensive one. Leave `--log` off such
a rule: nothing rotates that file, and a line per letter buries every deliberate press in it.

**A backgrounded app answers `AXFocusedUIElement` with nothing.** So a one-off `--dry-run` from a
shell cannot check anything conditioned on focus — the app is not frontmost while you run it, and the
option reports `focused=none` rather than reporting what it would do. A dry run *polled in the
background* while the user drives the app is another matter, because the app is frontmost then:
ChatGPT's poll read `editing=AXTextArea` turning into `focused=AXMenuItem` across a press. That is how
to learn where focus lands without a rule; the rule itself, with `--log` on, is the other way.

**Rules send the helper requests, because launching it was most of what a press cost — and all of it
after an idle spell.** A one-shot call re-spawns itself to disclaim responsibility, so it pays two
launches of a binary macOS has to vet, then tccd checking its signature and a preferences read before
it looks at anything. Warm, that is a few tens of milliseconds. Cold, the same call was 0.67s
— the first Cmd+Shift+U of a morning, 18 idle hours in, with swap at 17.8 of 18.4 GB — while its own log
line said `total_ms=223`, because that clock starts after both launches. Of the 0.45s it could not see,
90ms was the launch checks (the certificate lookup above, 62ms of it) and 305ms was the first stage
running before it spawned the worker, a step that takes 18ms warm; inside its clock, tccd took 64ms
and cfprefsd 66ms. A served request pays the `sh` Karabiner spawns and an `nc`, both platform binaries,
which the launch checks pass over, and the server has long since been through tccd and every framework
it uses: `launch_ms` 5-23ms, and 23-42ms
from the shell starting to the press, over six presses. Warm, from a terminal, the two shapes cost the
same (~30ms: bash's own startup and the pipeline's fork dominate), so the saving is the cold path's,
and `launch_ms` on the first press after an idle spell is what shows whether it held. A script
interpreting a dump still adds its interpreter's startup (node, ~70ms), so a rule that reads the tree
to decide something costs a dump plus an interpreter, and the question is not whether the decision is
worth having but whether it is worth doubling the rule: Cmd+Option+. archived a chat in one launch
plus the menu's own accelerator, and the same archive choosing its successor took four. Slimming the
binary was not the lever: on this macOS a C program that only returns loads the same ~600 dylibs the
helper does, because libSystem's own closure reaches Foundation, so dropping AppKit would have saved
initialisers and a few hundred page touches but not the launch.

**The helper is a resident server; a rule is a request.** `scripts/build-ax-press.sh` writes
`~/Library/LaunchAgents/com.raine.karabiner-config-ax-press.plist`, whose `Sockets` entry has launchd
own `scripts/bin/ax-press.sock` and start `karabiner-config-ax-press --serve` on the first connection;
the server takes the socket with `launch_activate_socket` and stays up. The build ends with
`launchctl kickstart -k gui/$(id -u)/com.raine.karabiner-config-ax-press`, so no server outlives the
binary it was started from, and the restart also spends a new binary's one-time first-launch scan — a
notarization lookup over the network and an XProtect pass, a few hundred milliseconds, cached per
file — before any press can. `launchctl print gui/$(id -u)/com.raine.karabiner-config-ax-press` says
whether it is running, how many times launchd has started it, and its last exit code. A request is the
arguments, each NUL-terminated, then end of file; the reply is what a one-shot run would print, then a
last line `exit=<code>`. macOS's `nc -U` half-closes once its input ends and prints the reply until the
server closes, then exits 0 whatever the code said, which is why chains are `--then` and not `&&`.
Requests run one at a time, so a `--wait` or `--scroll-to-end` holds up whatever arrives behind it.
`NSRunningApplication` needs no run loop to stay current in a process that lives for days: a dummy app
launched, killed and launched again showed up under each new pid on the very next call. `ProcessType
Interactive` in the plist is deliberate: a job left standard gets a daemon's limits, and
Karabiner-Console-User-Server, one of those, runs at scheduling priority 20, where an app runs at 31 or
above.

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
observes `NSWorkspace.voiceOverEnabled` instead) — but the Claude desktop app still accepts
`AXManualAccessibility` (returned 0), and on 2.110 that set is what brings, 2s later, the complete
mode an AXPress needs. Exposing the tree and acting on a press are separate thresholds: a freshly
launched Claude app answered the first press's search at once and dropped the press
([accessibility-modes.md](accessibility-modes.md)). The app decides; the role read is the only switch
known to expose the tree everywhere it has been tried.
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
`--dump` walks *forward*, so its numbering is document order and the default search returns the
*last* match listed — read the dump that way round before choosing, because getting it backwards
picks exactly the wrong flag. That ordering is also a discriminator on its own when the rivals sit
at opposite ends: Shortwave's toolbar Compose button and the Settings sidebar's Compose row carry
the same label, and the sidebar is the later of the two, so the default walk finds it and `--first`
would find the button.

**`--sibling` sees through wrappers.** An unlabelled AXGroup holding one child is not counted as a
level on either side: the match climbs out of its wrappers to find its row, and each child of the row
is read through its own. ChatGPT began wrapping each composer control in such a group, and with plain
parent-and-children semantics the picker and "Add files and more" stopped being siblings, so the
Cmd+Shift+F rule logged `found=false` in both modes with nothing else wrong. A rule that goes quiet
after an app update is worth a `--dump-all` around the qualifier before anything else.

**Direction is not a discriminator, and neither is `--sibling`, when the rivals share a parent.**
`--sibling` asks whether *some* child of the match's parent carries the label, so it selects a whole
row at once rather than a member of it — and if the row's parent also holds unrelated controls, they
are in the set too, which is how a reverse walk aimed at a folder row landed on the usage meter.
When two controls share their role, their parent, and a label that is plain varying text — the
Claude app's folder row puts a local/cloud popup immediately before the project picker — only their
order separates them, and `--nth` takes the nth match in walk order, counted per window. Reach for
it last: an ordinal breaks silently when the app inserts a control ahead of the target, so a label,
a distinct role or a sibling outside the row is worth more when one exists.

**A qualifier has to be in the row in every state the screen has.** A control the app only renders
once something is chosen — the folder row's add-another-folder button appears with a folder and not
without one — qualifies the row in the state you dumped and empties the match set in the state you
did not, and the rule then does nothing at all rather than something wrong. Prefer a sibling the row
always carries, even one whose label is a mode rather than a name, and say in the comment which mode
it assumes. `found=false` in `.claude/ax-press.log` is what this looks like after the fact: a press
that matched nothing, distinct from a press that landed on the wrong control.

**When the target's label changes with the screen, qualify the row and wildcard the label.**
ChatGPT's composer picker is `AXDescription="Select ChatGPT model"` in Chat mode and an `AXTitle`
naming the model in Work mode, with nothing in common; `"{}" --role AXPopUpButton --sibling "Add
files and more"` finds it in both, because the attach button is in that row on every screen. The
wildcard lets in every popup in the row, so the walk direction decides between them — Work mode's
permissions popup shares the row and comes first — with the same fragility as `--nth` above.

**A target the session can put up itself needs no visit.** The suggested-task chip is rendered by a
`spawn_task` call from the session on screen, so the agent building a rule for it can raise one,
poll `--dump` until the label appears, and `dismiss_task` afterwards -- the user only has to be
looking at that session. Ask for a visit only for state the tools cannot produce.

**A state the helper refuses to navigate to is captured by polling while the user visits it.** The
press refusal outside Karabiner (see the confused-deputy note) means a screen cannot be reached from
a shell, only read once someone else is on it — so loop `--dump`, and the competing `--dry-run`s,
against the state you are designing for, ask for one visit, and read the capture afterwards. Two
selectors compared inside one loop iteration are compared against the same tree, which is what a
dump taken before the visit and a dump taken after cannot promise.

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
emoji, and they are **not unique** — two projects can each hold a chat with the same title, so a
title does not identify a row and a search for one lands on whichever comes first. What does say
which project the current chat is in is the header again: beside the rename button it carries an
`AXPopUpButton` titled with the project's own name. The Chat tab's header was not inspected. The suggested-task chip (top right of the transcript) is a
split button: an `AXGroup` *described* with the primary label wraps an `AXButton` *titled* with it
and an `AXPopUpButton` described `"More start options"`, so a search for the label without
`--role AXButton` can land on the group. The label is whichever start target the app chose
(`Start with worktree`, `Start locally`, `Send to cloud`, ...), so the popup is the stable handle.

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
