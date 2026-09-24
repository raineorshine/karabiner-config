# System shortcut rules

## Driving a macOS system action from a rule

**A modifier-only system hotkey cannot be synthesized, and an ordinary chord can.** macOS handles a
double-tap binding — right-Command twice, the globe key — below the layer either `CGEvent` or the
accessibility API injects into. Dictation's trigger was measured against every route: Fn keyDown/keyUp,
Fn twice, Fn as a `flagsChanged` event, right-Command twice as real events and as flags, `key code 63`
through System Events, and the same presses delivered through Karabiner's own virtual HID device by a
temporary rule. **None started Dictation.** A synthetic ⌘Space opened Spotlight on the first attempt in
the same conditions, so the failure is the binding's shape, not synthetic input.
(`~/projects/vocalize/docs/macos-input-surfaces.md` lists every variant with its result — do not retry
them.)

So the way in is to **rebind the system hotkey to an ordinary chord and emit that**. The rule then looks
like any other: one `to` entry, no helper, no accessibility grant, and it works in every app.

**Pick a chord the keyboard cannot produce.** F13–F19 are absent from the internal keyboard, so
⌃⌥⌘F18 can only ever come from Karabiner: nothing fires it by accident, and it cannot collide with an
app's own shortcut. It also keeps the record readable — a chord in the Keyboard Shortcuts panel that
no key can reach is self-documenting as a machine-to-machine trigger.

**The rule now depends on machine state outside this repo.** The config loads and the rule fires either
way; what fails is the far end, silently, on a machine where the record was never written. Check it
before suspecting the rule:

```bash
/usr/libexec/PlistBuddy -c "Print :AppleSymbolicHotKeys:164" ~/Library/Preferences/com.apple.symbolichotkeys.plist
```

## Rebinding the record

`164` is Dictation. It shipped as `type = modifier` with parameters `8388608 4286578687` — right-Command
twice, which this machine could not fire by hand either, since `right_command` is remapped to escape.

```bash
osascript -e 'tell application "System Settings" to quit'
defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 164 '<dict><key>enabled</key><true/><key>value</key><dict><key>parameters</key><array><integer>65535</integer><integer>79</integer><integer>1835008</integer></array><key>type</key><string>standard</string></dict></dict>'
/System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u
```

- `65535` is the character (none — a function key), `79` is F18's virtual keycode, `1835008` is
  control+option+command (`262144 + 524288 + 1048576`).
- **Quit System Settings first.** An open Keyboard pane flushes its stale model over a correct external
  edit.
- **`activateSettings -u` loads the table into the current login session.** No logout, no reboot.
- Write the fragment as typed XML through `-dict-add`, and touch only the one ID. OpenStep-style
  literals can store the integers as strings, and a whole-domain import takes unrelated mappings with
  it.
- **The chord is a toggle, and a synthesized one.** 270ms from the chord to
  `DictationIMNotificationStartedListening`, 70ms from the second chord to `StoppedListening`, injected
  into the Claude app with nothing frontmost changed.

## Owning the fn key

**Karabiner grabs `fn`, and `to_if_alone` on it works.** A tap is a clean trigger: it fires on release,
and the 1s `to_if_alone` timeout means holding fn as a modifier never fires it.

**Re-emit fn in `to` or the key loses its modifier role.** `"to": [{ "key_code": "fn" }]` holds fn down
for as long as the physical key is held, which is what keeps fn+arrow, fn+delete and the function-key
row working while the tap belongs to the rule.

**A complex modification's output still goes through the `fn_function_keys` translation.** A manipulator
that consumes fn as a mandatory modifier and emits a bare `f1` produces the *brightness key*, because
nothing holds fn by the time that stage runs — measured on the fn+Shift row, which adjusted screen
brightness until every `to` entry was given `"modifiers": ["fn"]`. The Claude Go-menu rule emits `f2`
with `["fn", "control"]` for the same reason.

**What the tap costs:** the macOS double-fn trigger (`AppleFnUsageType = 3`), since Karabiner consumes
the key before the OS sees it. That is the trade — a single tap in place of a double one.

## Reading the result back

**Dictation posts its own edges, with no permission at all.** `DictationIM` sends
`WillStartListening`, `StartedListening`, `DidEnterDictationMode`, `DidExitDictationMode` and
`StoppedListening` to the distributed notification center; a 20-line observer on those five names
timestamps a press without a screenshot or a menu-title read. `DidExitDictationMode` fires spuriously
while Dictation is idle, and `DidEnterDictationMode` and `WillStartListening` fire for a start that
then stalls, so key on `StartedListening` alone.
(`~/projects/dictation-glow/docs/detection.md` establishes the names.)

**Inject the chord through System Events, not `CGEvent`.** `key code 79 using {control down, option
down, command down}` starts Dictation; a `CGEventPost` of keycode 79 with the same three flags, from a
shell that holds Accessibility, never reached the hotkey (no `Dictation Hotkey start triggered`).

**A start that hangs at the HUD is the target app, not the rule.** `DictationIM` logs `Dictation Hotkey
start triggered` for every tap that reached it, so a tap that shows the microphone HUD and never
listens has already done its part. In the one cluster measured, each start stopped at
`WillStartListening` and `DictationIM` logged `IMKServer Stall detected` about 6s later, blocked on the
Claude app answering where the insertion point was, 1.2s after an archive. Taps of the same rule
before and after listened normally. Read those two lines with
`/usr/bin/log show --predicate 'process == "DictationIM"'` before touching the rule.

**Which key actually arrived is read with a raw key echo** — it is what caught the
`fn_function_keys` translation above, since a media key and a plain F-key look identical everywhere
else. See [debugging.md](debugging.md).

**Do not force an app frontmost to probe it.** A sweep that activated the target every twelve seconds
while the user was working scored a press at 70% in one app and 100% in another, and the whole spread
was the user pulling focus back between the check and the press. The null it produces is
indistinguishable from a real one.

**A synthesized Dictation press dictates into whatever the user is typing in.** Its start and stop
land in the focused field of the frontmost app, which is the user's while they work, and each start
interrupts them. Ask before a probe that injects the chord, and run the batch once they have said the
keyboard is free.
