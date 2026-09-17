# Debugging and measurement

## Debugging rules that misbehave

Learned the slow way on the Notion archive and Messages tapback rules:

- **Which rules broke together names the mechanism, before any one of them is opened.** Two
  Claude-app shortcuts stopped working right after the app updated, which reads as the app having
  changed those two controls. They were simply the two `ax-press` rules pressed often enough to
  notice: every coordinate-click and plain-remap rule still worked, and so did four other `ax-press`
  rules nobody had reached for. The helper had lost its Accessibility grant. Partition the working
  and failing rules by *mechanism* — accessibility, coordinate click, plain remap, menu bar — before
  opening any of them, and when the `ax-press` set is the one that is down, read `trusted=` in
  `.claude/ax-press.log` first; its last line answers it without a press. When the pattern is in
  time instead — an `ax-press` rule that does nothing on its first press after the app launches and
  works on the next — it is the app's accessibility mode, not the rule
  ([accessibility-modes.md](accessibility-modes.md)).
- **Instrument inside the script.** It runs in the context that holds the permissions, so having it
  append what it saw — pointer position, whether the popup's window existed, how long it waited —
  turned "it stops short sometimes" into "the right-click produced no menu in 5 of 6, within 300ms"
  in a single round of presses. Ask the user for a batch and count, rather than one press at a time.
- **To learn what the app does *to itself* after a press, have the rule dump in a loop.** One
  keypress then buys the whole timeline. A build that archived and then wrote about forty passes of
  `--dump` to a file showed the app's own navigation landing after the rule's last press, and what it
  landed on — neither of which the press's own log line can show. A dump is a read, so it needs no
  permission the rule does not already have, and it costs one press instead of a round of presses per
  hypothesis.
- **Capture the screen from your own shell, not from the rule.** The shell has Screen Recording
  where the Karabiner-spawned script may not, so a capture loop gated on the target app being
  frontmost collects the pixels to measure while the user drives the UI. Measure the result in
  code — colour runs along a row and column give exact edges; eyeballing a crop does not.
- **A plain remap can log that it fired.** Append `{ "shell_command": "echo <rule> fired" }` to
  the `to` list; each press lands as a line in
  `~/.local/share/karabiner/log/console_user_server.log`, so one batch of presses separates "the
  rule never matched" from "the app ignored what it was sent". Remove it before shipping.
- **When a remapped chord misses and the direct chord does not, the emitted event is the
  difference.** Ten presses of each, counted, is the control: the Calendar Ctrl+arrow rule fired on
  every press and still landed about half of them, while the same chord pressed by hand landed all
  ten — so the app, not the rule, was reading something Karabiner sent differently. See
  docs/pauses.md for what that turned out to be.
- **Use a control.** Clicking an always-visible button (the sidebar search icon) with the same
  sequence separated "synthetic clicks work in this app" from "this button is special" in a single
  press, after many rounds of theorizing had not.
- **Small samples lie near a threshold.** Once failures are probabilistic, "worked every time" over
  a handful of presses cannot distinguish 100% from 90%. Three configurations passed a short test
  and then failed in use, so a pass at one value is a data point, not a floor. This cuts against
  *removing* a pause on thin evidence as much as against keeping one — the default is zero, but a
  10/10 at zero is what licenses shipping it, not a hunch that the pause looked pointless.
- **Seek the floor by binary search, and ship the floor.** Picking a value that feels safe and
  stopping there is guessing dressed up as caution: it leaves the real cliff unmeasured, so every
  later misfire reopens the whole question instead of moving a known number. Drive each pause down
  until it actually fails, with enough trials per value that a probabilistic failure shows up, and
  use what you measured. Do not hand-wave a split between pauses that "wait on a real transition"
  and ones that do not; measure each. Cmd+Shift+G's click-to-keystroke gap was predicted to be the
  real one of its two, on the reasoning that it waits for focus to move. It measured 0/0 alongside
  the other. A transition being real does not mean anything is racing it.
- **A pause you cannot point at a measurement for is a race, not a margin.** The 200ms hold the
  click rules used to cover `restore-mouse-position.js` reading the cursor measured p50 101ms over 400
  samples — but the tail reached 300ms and once 963ms, so it silently loses a percent or two of
  presses. It reads as a comfortable 2x margin and is really a coin flip against the tail. Measure
  the distribution and size the constant to that, not to the typical case — or remove the spawn the
  constant is covering, which is what actually fixed those rules.
- **When the last keystroke is destructive, measure a marker key instead.** That is where the archive
  rule's floor came from; the method, and the traps in it, are in "Measuring against the Claude app
  with video" below.
- **Bisect the underlying UI, not the rule — from a shell that holds Accessibility, which a Claude
  desktop session's does.** Karabiner cannot be triggered synthetically: it grabs the physical
  device, so injected CGEvents never reach its rules. The transitions the pauses cover are plain macOS
  behaviour and can be replayed and bisected automatically, turning a floor search from dozens of hand
  presses into an unattended sweep — which needs Accessibility, and the grant follows whichever app
  started the shell. A session in the Claude desktop app runs its commands as that app, which holds
  the grant: a scratch Swift probe reported `AXIsProcessTrusted()` true, pressed controls, wrote
  attributes and closed a menu with an Escape posted by `CGEventPostToPid`, and the accessibility-mode
  sweep in [accessibility-modes.md](accessibility-modes.md) ran that way. Earlier, from a shell without
  the grant, `osascript` got "not allowed to send keystrokes" (System Events error 1002) while Automation to System Events
  *was* granted, so a harmless call like `get name of first process` succeeded and made the permission
  look present. Check with an actual keystroke from the shell the sweep will run in. When it is
  unavailable, every trial costs a human press — see the video section for how to spend them.
- **A model that needs revising every round is the signal to stop tuning.** Five plausible models
  each explained the evidence and then broke. Stop turning knobs and find a decisive measurement.
- **Measure end-to-end.** A latency figure summed from a script's sleep constants was wrong about
  where the time actually went; timing the real command settled it in one step.
- **A slow press is timed from the keypress, and a helper's own clock starts late.** The first
  Cmd+Shift+U of a morning logged `total_ms=223` and took 0.67s: the rest was spent before the helper
  could start a clock. `launch_ms` in `.claude/ax-press.log` now covers that part, from the `sh`
  Karabiner spawned. For the breakdown, `/usr/bin/log show --info` around the press has it, one daemon
  at a time: amfid's `Entering OSX path for <binary>` (launch checks), launchd spawning
  `taskgated-helper`, syspolicyd's `provenance data on process: <pid>` (one per exec, so the gap
  between two is a stage's run time), tccd's `REQUEST_MSG` and reply, then the `cfprefsd` and
  `launchservicesd` connections. Not every `sh` is the press: Karabiner-Console-User-Server spawns
  `sh`, `bash` and its own service-status helpers every three seconds, so match the shell to the
  helper's pid rather than to the nearest `running binary "sh"` line. Read it the same day: a day on, the default-level lines (amfid's
  verdict, launchd's spawn) were still there and the info-level ones (syspolicyd, tccd) were gone.
  `log` is a zsh builtin, so call `/usr/bin/log`. Check the machine before the helper: swap at 17.8 of 18.4 GB
  made every cold daemon on that path slow at once, which no change to the helper removes.
- **A helper that builds its log path from `getenv("HOME")` once exited non-zero and wrote nothing,**
  so the instrumentation failed silently and looked exactly like the rule never firing. The ChatGPT
  rule's `shell_command` has since logged `HOME=/Users/raine`, so the shell does get `$HOME`; what the
  earlier helper saw is unexplained. Hardcode absolute paths in anything a rule spawns anyway — it
  costs nothing — and put a `date >> log` marker in the same `shell_command` (joined with `;`) so
  "never fired" and "fired and died" are told apart in one press.
- **Instrument the config that ships, not a copy of it.** A probe pointing at a scratch copy of
  `mouse-click.js` failed while the open question was whether the real one worked — that adds a
  variable instead of removing one. Install the actual candidate and measure that.
- **A listen-only `CGEventTap` from your own shell is not an instrument here.** `CGEventTapCreate`
  returns a valid port and then delivers nothing, not even ordinary clicks, so an empty log reads as
  "the click never happened" when it means "the tap never worked". Prove an instrument sees a known
  event before trusting its silence. Bracketing the rule with its own timestamps is more reliable.
- **Two JXA traps that only bite once the call works.** `String(someNSString)` yields the literal
  `[id __NSCFString]` — use `ObjC.unwrap()`; it silently replaced a trace log's contents. And an
  untyped `Ref()` throws `Ref has incompatible type` when an accessibility call *succeeds*, so a
  probe that returns an error for lack of permission looks healthy and only breaks once granted.

## Measuring against the Claude app with video

Where the archive rule's floor came from. The capture and analysis mechanics are general; **every
number and every claim about palette behaviour below is the Claude desktop app only**, and none of it
has been checked against another app.

**What the palette does (Claude app).** Typing into Cmd+K updates in two stages: the field and the
quick actions take the query immediately, while the contextual `Archive "<title>"` / `Delete
"<title>"` rows arrive only once the query resolves. Until they land, Enter belongs to `New chat
"<query>"` — its Enter badge turns red — and firing it posts the query as the first message of a new
chat. Lag from the last letter rendering to Archive owning Enter: 0-50ms idle over 15 presses typing
`archive`, and 17-83ms at 100% CPU load over 19 presses typing `arch`.

**Clicking the row is not the safer alternative there.** When the chat's title matches the query,
`Delete "<title>"` renders directly under `Archive "<title>"` — Archive spans roughly y 232-255pt and
Delete starts at ~257pt, with the window at 0,34 735x922. A click 13pt low deletes the chat. Before
the rows land, that same point is over the inert "Quick actions" header, so the early failure is
harmless and the late-aim failure is not.

**Presses are the scarce resource for anything a rule does.** Karabiner grabs the physical device, so
injected events never reach its rules, and the rule's own timing — its holds, its keystrokes — costs
a human press per trial. The app underneath can be driven without one from a shell that holds
Accessibility ("Bisect the underlying UI" above), but a measurement of the rule itself cannot. Design
for information per press.

**Marker probe.** Replace a destructive final keystroke with a harmless one at the same offset — for
the archive rule a `z`, which only extends the query — and read whether the UI was ready in the frame
the marker landed in. Read *only* that frame: anything the marker itself changes (the `z` restarts
the palette's query) makes every later frame a measurement of the probe, which inflated a "the row
needs 150-300ms" figure here before it was caught. Check the proxy against the real action in both
directions before trusting it. Here it predicted 3/3 failures that the real Enter reproduced, and the
value it produced was then confirmed by hand with the real Enter — worth doing separately, because
Enter runs the palette's command handler while `z` goes into the text field, so a marker that passes
is not by itself proof that the real key will. A hand confirmation is a handful of presses, though:
it rules out a broken proxy, not a rare false negative. Only ordinary use over weeks tests that.

**One generous delay beats a sweep.** A sweep spends presses to learn one bit each, and censors
exactly the presses that matter: a press at 50ms can never reveal that it needed 90. Run every press
at a delay high enough that all of them pass, and compute what each one *needed* — nominal minus the
gap between "ready" and the marker. 15 presses that way gave a full distribution (17-67ms); the
sweep's 19 gave four buckets of five with the interesting values censored.

**Include an arm that must fail.** The 0ms arm was a positive control. When it *passed*, the detector
was wrong rather than the app — the red badge's absence covers both "Archive owns Enter" and "the
palette has not reacted to the query yet". Without that arm the sweep would have read as clean.

**Encode the arm in the pixels.** Timing alone did not separate the delay arms under load; they
blurred into a continuum. Giving each arm a different number of marker keys (1/2/3/4 `z`s) made the
final query width name the arm exactly, and cost nothing, since the verdict is read at the first
marker's frame.

**Capture recipe.**

```
ffmpeg -f avfoundation -capture_cursor 0 -framerate 60 -i "3:none" \
  -vf "crop=W:H:X:Y" -c:v libx264 -preset ultrafast -crf 20 out.mp4
```

Device index from `-f avfoundation -list_devices true -i ""`. Crop in *screen pixels* (2x points on
this display) to the smallest region that answers the question — 980x210 here. A full-window 60fps
capture is heavy enough to perturb what it measures, and a `screencapture` shell loop tops out at
8-10Hz, far too coarse for a 17ms transition. `-vsync` no longer exists; it is `-fps_mode`.

**Extract frames with `-fps_mode passthrough` and take times from pts.** Without it ffmpeg pads to CFR
and frame indices stop matching `ffprobe -show_entries frame=pts_time` — 8069 against 8033 in one run
— which silently shifts every measurement. The capture also drops frames under load (51fps of a
requested 60), so index x 16.7ms is not a clock.

**Detector traps, each of which produced a confident wrong answer first.**

- A row's mean brightness mixes its dark background with its white text and lands *between* the two
  states. Use the minimum row-mean over the band, so the row's dark padding is what is detected:
  12 against 29 here, unambiguous.
- Bound every search to its own trial. A "when did the row appear" search that runs past the palette
  closing finds the *next* press and reports 1.6s.
- Walking back from the marker to a plateau finds its last frame, not its first. The reference has to
  be the first.
- Content behind the palette imitates a trial. Require a trial to pass through the states a press must
  pass through — empty field, then the query's width, then the marker — and require the row to start
  absent.

**What hand pressing cannot reach.** 17ms of resolution at 60fps, and ~20 presses characterise a tail
to roughly the 1-in-20 level. The far tail is not measurable this way. Say so next to the number
instead of implying the floor is airtight.
