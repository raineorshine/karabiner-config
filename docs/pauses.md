# Pauses

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
fixed by removing the spawn rather than by raising it. Exactly one survived contact unchanged — the
150ms hold on a right-click, which failed 5 times in 6 without it. That is what an earned constant
looks like: a failure count at a specific value, written next to it.

**And one turned out not to be a constant problem at all.** The archive rule's 120ms before Enter
failed 3 times out of 3 under CPU load. It went to 350ms on the first measurement, then back to 120ms
once the query it types was shortened from `archive` to `arch` — because what it was short against
was the app's backlog from its own seven keystrokes, and four keystrokes cost less. Ask what a pause
is waiting *behind*, not only how long the thing it waits *for* takes; the rule's own input is part
of the answer. A too-short pause also fails intermittently and blames itself on something else, which
is how that rule went a long time looking like a flaky app rather than a wrong number.

**That one then failed in ordinary use, the day it shipped.** 19 hand presses under a deliberate CPU
throttle put the requirement at 17-83ms and the floor at 100ms; 120ms shipped; a real press beat it
within hours, and the hold is now 150ms. Nothing in the measurement was wrong — it simply never
reached the tail, which is the documented limit of ~20 hand presses, and the limit was written next
to the number before it bit. Two things follow. A measured floor bounds the *typical* case; headroom
over it is a separate decision, and on a rule whose failure costs something, the floor is the wrong
place to ship. And when a rule with an earned constant misfires, raise that constant first — the
floor is not what is in doubt, and re-deriving it burns presses to re-learn what is already known.

**A hold is not always the slack the app sees — seen in the Claude app, untested elsewhere.**
`hold_down_milliseconds` delays Karabiner's *emission*, not the app's *processing*. The Claude app
renders a burst of keystrokes a few at a time (its palette field steps through visibly distinct
partial widths), so it is still draining them when the next event arrives, and the gap it experiences
is shorter than the constant — shrinking further under load, exactly when the pause was needed.
There, under CPU throttle: a 120ms hold after seven letters delivered Enter 67ms after the last
letter rendered, the other 53ms eaten by backlog; four letters cut that cost to about 30ms. Two
consequences *in that app*: count the keystrokes a rule sends as part of its cost, and size a hold
against a measurement taken at the app rather than the number in the config. Whether any other app
queues input this way has not been checked here, and the menu-bar sequence — which floors at zero
after 20 presses — is evidence that not everything does. Also measure under load: idle, that rule's
race did not reproduce at all in 15 presses.

**Say so when a value is un-searched.** Cmd+Shift+P keeps a 100ms gap not because it was measured but
because its target is the Create PR button and a binary search would fire it once per press. Its
comment says that outright, so the number is not mistaken later for a floor.
