# Pauses (`hold_down_milliseconds`)

## Default to none

**Never add a pause on speculation.** Not "just to be safe", not "this probably wants a moment", not
a round number carried over from a rule that looked similar. A constant in a rule is paid on every
press, forever, and an unnecessary one is invisible: nothing fails, so nobody goes back to check. A
pause that is genuinely needed announces itself the first time it is missing, and costs one round of
presses to add.

**Start at zero; adjust up only on evidence.** Add a pause when the rule has been *observed* to fail
without it, and size it to the failure that was observed rather than to how alarming it felt.

**Name the transition a pause waits on; if you cannot, there probably is not one.** A queued key
event waits its turn by construction — which is why menu-bar sequences floor at zero
([menu-bar-rules.md](menu-bar-rules.md)). A click races only when the thing it lands on is not there
yet: a hover-revealed button, or a popup still drawing. A click at a target already on screen races
nothing, which is why Cmd+P's warp-to-click gap went to 0.

## Finding the value

**Measurement has changed every constant it has touched here, in both directions.** Four went to
zero: the menu-bar sequence shipped at 150/150/150/120ms and passed 20/20 at 0; Cmd+P's warp-to-click
gap was 100ms and passed 10/10 at 0; Cmd+Shift+G's two gaps were 100ms each and passed 10/10 at 0/0 —
though the click-to-keystroke one had been predicted to be real, since it waits for focus to move. A
transition being real does not mean anything is racing it. One was too *small*: the 200ms covering a
cursor-restore spawn read as a comfortable 2x over its p50 of 101ms, but the tail reached 300ms and
once 963ms, so it silently lost a percent or two of presses; removing the spawn fixed it
([click-rules.md](click-rules.md)). Exactly one survived unchanged — the 150ms hold on a right-click,
which failed 5 times in 6 without it. That is what an earned constant looks like: a failure count at a
specific value, written next to it.

**Seek the floor; do not pick a value that feels safe.** Stopping at a comfortable number leaves the
real cliff unmeasured, so every later misfire reopens the whole question. Measure each pause
separately rather than guessing which ones matter, size to the distribution's tail rather than the
typical case, and let a 10/10 at zero — not a hunch — license removing one. Two ways to find it:

- **Binary search** when a trial is cheap: replayed from a shell ([debugging.md](debugging.md),
  "Replaying the UI without a press"), or a batch of hand presses per value that fire nothing
  destructive. Drive the pause down until it fails, with enough trials per value that a probabilistic
  failure shows up.
- **One generous delay and a per-press measurement** when each trial is a human press and a marker or
  video can show what each press *needed* — a sweep censors exactly the presses that matter
  ([debugging.md](debugging.md), "Measuring against the Claude app with video").

**Ship 25% over the measured floor, rounded to a sensible number — not the floor, and not 2x.** The
floor is the lowest value that passed its batch, and it bounds the *typical* case: the archive rule's
19 hand presses under CPU throttle put the floor at 100ms, 120ms shipped, and a real press beat it
within hours (now 150ms) — ~20 presses never reach the tail. The Calendar rule (`Calendar:
Shift+Up/Down → Ctrl+Shift+Up/Down`) failed at 40ms and passed 10/10 at 60ms, so it shipped at 75ms;
100ms was rejected as more than the evidence called for. The hold delays the key-*up*, not the
key-down, so its cost is not perceived latency but a cap on how fast the chord can burst or
auto-repeat. When a rule with an earned constant misfires, raise that constant first; re-deriving the
floor burns presses to re-learn what is known.

**Probe several values per round when the rule has equivalent chords.** When several chords emit the
same thing with the same hold — the Calendar rule's Shift+Up/Down and Cmd+Up/Down all send a
Ctrl+arrow — install a different candidate on each and ask for one batch of ~10 presses per chord;
three timings resolve in one round instead of three. Name each chord with its value in the ask
("Shift+Down at 10ms, Shift+Up at 25ms, Cmd+Down at 50ms"), and leave one chord at the last
known-good value as a control.

**Say so when a value is un-searched.** Cmd+Shift+P keeps a 100ms gap because its target is the
Create PR button and a binary search would fire it once per press. Its comment says that outright,
so the number is not mistaken later for a floor.

## What a hold is really covering

**Ask what a pause is waiting *behind*, not only how long the thing it waits *for* takes.** The
archive rule's 120ms before Enter failed 3 of 3 under CPU load. It went to 350ms, then back to 120ms
once the query it types was shortened from `archive` to `arch`: what it was short against was the
app's backlog from its own seven keystrokes. A too-short pause also fails intermittently and blames
itself on something else — that rule long looked like a flaky app rather than a wrong number.

**A hold is not always the slack the app sees — seen in the Claude app, untested elsewhere.**
`hold_down_milliseconds` delays Karabiner's *emission*, not the app's *processing*. The Claude app
renders a burst of keystrokes a few at a time, so it is still draining them when the next event
arrives, and the gap it experiences is shorter than the constant — shrinking further under load.
There, under CPU throttle, a 120ms hold after seven letters delivered Enter 67ms after the last letter
rendered; four letters cut the backlog to about 30ms. In that app, count the keystrokes a rule sends
as part of its cost, size a hold against a measurement taken at the app, and measure under load: idle,
that race did not reproduce at all in 15 presses. The menu-bar sequence is evidence that not every app
queues input this way.

**A hold on an emitted chord can be covering the modifier, not the key.** Karabiner releases a
modifier it added microseconds behind the key it modified, where a hand keeps the modifier down well
past the key. An app that reads the modifier state after the key-down — rather than the flags on the
event — then sees it about half the time. `hold_down_milliseconds` on the key keeps the modifier down
for the hold too, which fixes it; the Calendar Ctrl+arrow rule failed about half the time at 0ms and
carries the measurement. Suspect this when the direct chord lands every time and the remapped one
lands some of the time.
