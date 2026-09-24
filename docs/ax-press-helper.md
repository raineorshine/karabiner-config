# The ax-press helper

What keeps `scripts/ax-press.swift` (built as `scripts/bin/karabiner-config-ax-press`) working and
fast: the resident server rules send requests to, how it gets Chromium to expose a tree at all, its
Accessibility grant, rebuilding it, and what a press costs. Writing a rule against it is
[accessibility-rules.md](accessibility-rules.md).

## The resident server

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

## Getting a tree to walk

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

**Two traps in walking the tree.** It is not always a tree: a freshly launched ChatGPT answered with a
child that led back to an ancestor, and a naive recursion overflowed the stack (SIGSEGV, "excessive
recursion") — keep the ancestor path and skip anything on it. And an app with no window open answers
`AXFocusedWindow` with its own application element; insist on `AXRole == AXWindow`.

## The Accessibility grant

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

**Without the grant the helper cannot even look.** `--dump` and `--dry-run` report
`trusted=false` too, so it cannot be used to work out what to build next, and every rule relying on
it is down until the entry is re-approved. Read the tree with System Events instead while that is
true, on an app System Events can see — the Karabiner-settings work did ([accessibility-rules.md](accessibility-rules.md)), decided on two new capabilities (`--ancestor`, `--set`) plus
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

## Building it

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

## What a press costs

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
