# The ax-press helper

`scripts/ax-press.swift`, built as `~/.config/karabiner/scripts/bin/karabiner-config-ax-press` (the
main checkout's, whichever worktree builds it), finds a control in an app's accessibility tree and
presses it. It logs to the main checkout's `.claude/ax-press.log` — a worktree's copy of `.claude/` is
stale. This file is the helper itself: how it serves, how it is built, and how its Accessibility
grant survives. Writing a rule with it is [accessibility-rules.md](accessibility-rules.md).

## The resident server

**The helper is a resident server; a rule is a request.** `scripts/build-ax-press.sh` writes
`~/Library/LaunchAgents/com.raine.karabiner-config-ax-press.plist`, whose `Sockets` entry has launchd
own `scripts/bin/ax-press.sock` and start `karabiner-config-ax-press --serve` at login or on the first
connection; the server takes the socket with `launch_activate_socket` and stays up. The build ends with
`launchctl kickstart -k gui/$(id -u)/com.raine.karabiner-config-ax-press`, so no server outlives the
binary it was started from, and the restart also spends a new binary's one-time first-launch scan — a
notarization lookup over the network and an XProtect pass, a few hundred milliseconds, cached per
file — before any press can. `launchctl print gui/$(id -u)/com.raine.karabiner-config-ax-press` says
whether it is running, how many times launchd has started it, and its last exit code.

**The wire format.** A request is the arguments, each NUL-terminated, then end of file; the reply is
what a one-shot run would print, then a last line `exit=<code>`. macOS's `nc -U` half-closes once its
input ends and prints the reply until the server closes, then exits 0 whatever the code said, which
is why chains are `--then` and not `&&`. Requests run one at a time, so a `--wait` or
`--scroll-to-end` holds up whatever arrives behind it. A one-shot run from a shell takes the same
arguments, which is what `--dump` and `--dry-run` are for.

**Process details that are deliberate.** `NSRunningApplication` needs no run loop to stay current in
a process that lives for days: a dummy app launched, killed and launched again showed up under each
new pid on the very next call. `ProcessType Interactive` in the plist matters: a job left standard
gets a daemon's limits, and Karabiner-Console-User-Server, one of those, runs at scheduling priority
20, where an app runs at 31 or above.

**Rules send requests because launching the helper was most of what a press cost — and all of it
after an idle spell.** A one-shot call re-spawns itself to disclaim responsibility, so it pays two
launches of a binary macOS has to vet, then tccd checking its signature and a preferences read before
it looks at anything. Warm, that is a few tens of milliseconds. Cold, the same call was 0.67s — the
first Cmd+Shift+U of a morning, 18 idle hours in, with swap at 17.8 of 18.4 GB — while its own log
line said `total_ms=223`, because that clock starts after both launches. A served request pays the
`sh` Karabiner spawns and an `nc`, both platform binaries the launch checks pass over: `launch_ms`
5-23ms, and 23-42ms from the shell starting to the press, over six presses. Warm, from a terminal,
the two shapes cost the same (~30ms), so the saving is the cold path's, and `launch_ms` on the first
press after an idle spell is what shows whether it held ([debugging.md](debugging.md) has how to
time a press from the keypress).

**A rule that interprets a dump in a script pays that interpreter too** (node, ~70ms), so the
question is whether the decision is worth doubling the rule: Cmd+Option+. archived a chat in one
request plus the menu's own accelerator, and the same archive choosing its successor took four.
Slimming the binary is not a lever: on this macOS a C program that only returns loads the same ~600
dylibs the helper does, because libSystem's own closure reaches Foundation.

## Building

**The binary is shared across worktrees; the source is not.** `scripts/build-ax-press.sh` writes to
the *main* checkout's `scripts/bin/` whichever worktree it runs from, because that is where the
rules point, and restarts the LaunchAgent. A build from a branch behind `main` therefore replaces the
live binary with one missing whatever options landed meanwhile, and a rule that passes a dropped
option fails as an ordinary miss — nothing says the option is gone. Rebase before building, and build
again after shipping: the binary a test installed predates the ship's rebase.

**Building a helper change is installing it, so take the test lock first.** Every rule presses
through the one live binary, so an untested change is live the moment it builds — acquire before
building, then dry-run the new capability against the build.

**The live helper is under the test lock too.** A build swaps the binary and restarts the server,
so one run while another session is testing changes the code that session's presses go through —
a post-ship rebuild did exactly that to a session mid-test on the helper. `scripts/build-ax-press.sh`
therefore refuses while `scripts/karabiner-test-lock.sh` is held by another worktree, and lets the
holder's own builds through. A refused post-ship rebuild is deferred, not dropped: check `status`
again before the session ends and build once it reads `unlocked`, and if it never does, name the
pending rebuild in the report with the command.

**Check the live helper is the build under test before reading a press.** Another session's ship can
rebuild it from main at any time. Search the binary for a report key the change added (Python over
the file's bytes; `strings` is an Xcode shim here), and pick a key longer than 15 bytes: Swift inlines
shorter literals into the code, so a missing `AXPopUpButton` proves nothing.

**The Xcode tools can refuse to run at all.** `swiftc`, `otool` and every other `xcrun` shim exit
with "You have not agreed to the Xcode license agreements" after an Xcode update. The build falls back
to the Command Line Tools' own `swiftc`; a probe run by hand needs
`DEVELOPER_DIR=/Library/Developer/CommandLineTools` the same way (or
`/Library/Developer/CommandLineTools/usr/bin/llvm-otool` for `otool`).

**A new label never needs a rebuild; a new capability does.** The helper takes everything as
arguments, so a rule is arguments. `--action` and `--label-from` were new capabilities, `--wait` and
`--key` another; an option general enough that the rule after it is arguments again is the cheaper
shape.

**Two traps in walking the tree.** It is not always a tree: a freshly launched ChatGPT answered with
a child that led back to an ancestor, and a naive recursion overflowed the stack (SIGSEGV, "excessive
recursion") — keep the ancestor path and skip anything on it. And an app with no window open answers
`AXFocusedWindow` with its own application element; insist on `AXRole == AXWindow`.

## The Accessibility grant

The grant is the `karabiner-config-ax-press` row in System Settings → Privacy & Security →
Accessibility.

**Accessibility goes to the helper itself, which is what makes it predictable.** TCC judges a
command-line tool by whatever launched it — a terminal, or Karabiner — which is why the same script
can post events from one rule and not another ([click-rules.md](click-rules.md)). The helper
re-spawns itself with `responsibility_spawnattrs_setdisclaim`, the private posix_spawn attribute
Chromium uses for its own helpers, so the child is judged as the binary wherever it was launched
from: granted once, it reported trusted=true from a shell and from Karabiner alike. The resident
server needs no disclaim: a process launchd starts is its own responsible process. The binary is
named `karabiner-config-ax-press`, not `ax-press`, so the Accessibility list says whose it is.

**TCC keys the grant to the binary's path and its designated requirement, so the signature decides
what the grant survives.** A plain ad-hoc signature carries an implicit requirement that pins the code
hash, which changes with every compile: six regrants in the session that built the helper, and one
more months later, when a rebuild took every ax-press rule down at once and read as a Claude app
update having broken the two of them anyone had pressed. `scripts/build-ax-press.sh` signs ad-hoc
with an *explicit* requirement, `designated => identifier "com.raine.karabiner-config-ax-press"`, and
TCC stores exactly that with the grant (tccd logs `CodeReq: identifier "…"` as it writes the row).
Only changing that identifier, or where the binary lives, costs a regrant now. Read
`~/projects/axshot`'s `docs/permissions.md` before designing anything else against TCC here.

**Do not go back to a self-signed certificate.** It also survived rebuilds, but amfid cannot chain it
to Apple, so it asked `taskgated-helper` for a provisioning profile on every cold start — 62-111ms
when launchd had to start that helper — and the answer lapsed after about half an hour idle, exactly
when presses are slowest. An ad-hoc signature leaves amfid in 1ms. The certificate protected little
besides: its key was on `codesign`'s access list with Always Allow.

**Rebuilding unchanged source is not a test of the grant.** `swiftc` is deterministic here and
re-emits a byte-identical binary, so the code hash never moves. Move the hash first: an `-Onone`
build moved it, and the grant held for the server and a one-shot run alike.

**Without the grant the helper cannot even look.** `--dump` and `--dry-run` report `trusted=false`
too, and every rule relying on it is down until the entry is re-approved. Read the tree with System
Events meanwhile, on an app System Events can see ([accessibility-rules.md](accessibility-rules.md)).
`trusted=` on the last line of `.claude/ax-press.log` answers whether the grant is there without a
press.

**Regranting means deleting the entry, and the deletion empties the list, so run the helper again.**
Toggling the existing `karabiner-config-ax-press` entry off and on does not re-request: the stale
requirement is still what the entry records. The user removes the row with `-`, and the row comes
back only when the binary next asks. A dry run sent every two seconds brings it back the moment it is
deleted, so the user can switch the fresh entry on in the same visit, and the loop ending on
`trusted=true` is the grant taking effect:

```bash
until ~/.config/karabiner/scripts/bin/karabiner-config-ax-press com.anthropic.claudefordesktop x --dry-run | grep -q trusted=true; do sleep 2; done
```
 The server exits after answering `trusted=false`: a process reads trust
once, so a server started without the grant would refuse every press until restarted.

**A copy of the helper at another path is a stranger to TCC, and asking makes it a row.** A copy
answered `trusted=false`, and the question alone added a switched-off row for the copy's path to the
Accessibility list — rows only the user can delete. Probe a copy's signing or launch cost through the
no-argument usage path, which exits before any accessibility call.

## It presses only for Karabiner

**A helper that carries its own grant is a confused deputy, so it refuses presses from anyone but
Karabiner.** The server answers anyone who can reach its socket, which would let any process running
as the user press any labelled control in any app. So the helper refuses to press unless
`Karabiner-Console-User-Server` is among the ancestors of whoever asked (checked by full path, under
root-owned `/Library`, not by name): its own for a one-shot run, and for a served request the process
on the far end of the socket, which the kernel names (`LOCAL_PEERPID`) — the `nc` a rule runs, under
Karabiner's `sh`. A press sent from a shell comes back `refused=not-launched-by-karabiner
ancestors=nc<zsh<…`. `--dump` and `--dry-run` stay usable from a shell, and the helper logs to one
fixed file rather than a path from its arguments.

So testing a real press always goes through the rule, and the keypress is the user's: keys a
computer-use tool posts are CGEvents, downstream of the HID grab where Karabiner reads the keyboard,
so no rule ever sees them. What an agent can check without a press is in "Verifying a rule" in
[accessibility-rules.md](accessibility-rules.md).
