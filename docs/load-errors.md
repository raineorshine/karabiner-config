# Load errors (why a reload can succeed and a rule still never load)

Karabiner does not refuse a config it can only partly parse. It drops the manipulator it cannot
read, loads the rest, and reports the reload as a success, so the rule just never fires. That
happened twice before `scripts/karabiner-test-lock.sh install` learned to check for it: Karabiner's
own linter before the file goes live, and the daemon's log after the reload.

## The moving parts

**Two processes reload the live file, each on its own clock, and only the daemon builds rules.** The
root daemon (`Karabiner-Core-Service`, lines tagged `[core_service (daemon)]`) logs to
`/var/log/karabiner/core_service.log`, which is world-readable. The console user server logs to
`~/.local/share/karabiner/log/console_user_server.log`. Both log `Load <path>...` and then
`core_configuration is updated.` for every change of content. `~/.local/share/karabiner/log/core_service.log`
has the same name but belongs to a third process, `core_service (agent)`, and carries no config
errors.

**A manipulator the daemon cannot parse is dropped after its reload has already succeeded.** The
daemon builds the rules after logging its own "updated", and logs each one it cannot build a few
milliseconds later as `[error] ... karabiner.json error: <reason>` — so far always an unknown
`comment` key inside a manipulator. The message dumps the manipulator, truncated, and does not name
the rule. The user server's "updated" has landed both before and after that error, and nothing is
logged when the rules are done, so a check has to wait a moment past the daemon's "updated" before
the absence of an error means anything.

**A file the parser refuses as a whole never logs "updated".** A rule with a missing or empty
`manipulators`, for one, logs `[error] ... parse error in <path>: ...` in both logs instead, and the
user server raises the settings window's doctor alert (`settings_window_guidance_alert changed: none
-> doctor`).

**Both logs rotate at 256KB,** `x.log` to `x.1.log`, so a byte offset taken before a reload can point
past the end of the file by the time the reload's lines arrive.

## What install checks

**Karabiner's linter first, over the rules only.** `karabiner_cli --lint-complex-modifications` runs
Karabiner's own parser: it rejects unknown keys at every level (the manipulator, `from`, `to`, a
condition), an unknown `key_code` or manipulator `type`, and an empty `manipulators`, and it names
the rule by its `description`. Install refuses a file it rejects, before the live config is touched.
Its quirks:

- It reads a rules file for distribution, `{"title": ..., "rules": [...]}`. Given a whole
  `karabiner.json`, or the rules without a `title`, it misreads the object as a single rule and
  reports `manipulators` missing or empty.
- Its argument is a glob, and a glob that matches nothing passes: exit 0, no output. Install pipes
  the rules to `/dev/stdin` instead of writing a file whose path could miss.
- `--silent` drops the path prefix and the `ok`, leaving only the errors, on stdout.

**Then the daemon's log, for everything outside the rules.** Once the user server reports the
reload, install waits for the daemon's own outcome, waits past the errors' lag (the measurement is in
`rejected`'s comment), and exits `REJECTED` with every `[error]` line after this reload's `Load`. The
verdict is kept in the lock: a file that has not changed does not reload, so retrying a rejected file
repeats its verdict instead of passing.

**Limit: a file refused as a whole waits out the user-server wait's 10s** before its error is
reported, since that wait stops only on "updated". The linter catches the rule-level cases first.

## Dead ends

**A hardcoded list of allowed manipulator keys.** The list first proposed for the lint (`type`,
`from`, `to`, `to_if_alone`, `to_if_held_down`, `to_after_key_up`, `to_delayed_action`,
`conditions`, `parameters`, `description`) lacks `to_if_other_key_pressed`, which Karabiner 16.3.0
accepts, so it would have refused the first valid rule to use it — and it sees nothing below the
manipulator's own keys. `strings` on the daemon binary does not yield a better list: short key names
are compiled inline, although class names such as `basic::to_if_other_key_pressed` show which exist.

**Taking the user server's "updated" as the end of the reload.** The daemon's error has landed 2ms
after it.

## Changing the lock script

**`/bin/sh` is bash 3.2, where `set -e` depends on how a function is called.** A function called from
`if`, `until`, `||` or `&&` runs with errexit off for its whole body, so `replace_live "$2" || ...`
would carry on past a failed `mv`. `x=$(f)` keeps errexit on inside `f`, and a failing command stops
`f` there. Call `replace_live` bare, and end a function whose output is captured on something that
returns 0.

**Test it without the live slot.** Point `KARABINER_ROOT`, `KARABINER_LOG` and `KARABINER_DAEMON_LOG`
at a scratch directory, and run a small process that watches the scratch `karabiner.json` and appends
the lines a reload writes, with whatever lag, error or rotation the case needs. A rotation case needs
a log larger than what follows the rotation, as Karabiner's are: the check compares sizes, and
back-to-back rotations of tiny logs fool it.

**Against the real daemon, skip the linter with `KARABINER_CLI=/nonexistent`,** so a bad manipulator
reaches the daemon, and make the test rule one that cannot fire: a chord nobody presses, conditioned
on a bundle identifier that never matches. It takes the lock but no presses.
