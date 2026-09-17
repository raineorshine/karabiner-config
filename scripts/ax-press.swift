// Find a control in an app's accessibility tree by its label and press it.
//
// For a target whose position depends on the content around it, such as the Copy button beneath
// the last ChatGPT response, no fixed coordinate can reach it. The accessibility tree can: the
// button is there as an AXButton carrying its label, with a frame that can be read, and AXPress
// activates it without moving the pointer at all. Chromium and Electron expose the DOM this way,
// so this reaches into web apps as well as native ones.
//
// Accessibility permission is granted to a process by TCC, which attributes a command-line tool to
// whatever launched it: a helper spawned by Karabiner is judged as Karabiner, and the same helper
// run from a terminal is judged as the terminal. That is why one Karabiner-spawned script can post
// events while another cannot (see AGENTS.md). This tool sidesteps the question by re-spawning
// itself with the responsibility disclaimed, the same private posix_spawn attribute Chromium uses
// for its helpers, so the child is judged as ax-press itself wherever it was launched from. The
// grant then goes to this binary alone, not to a terminal, not to osascript, not to Karabiner.
//
// TCC keys that grant to the binary's path and its designated requirement. scripts/build-ax-press.sh
// signs ad-hoc with an explicit requirement that names only the signing identifier, so a recompile
// still satisfies the grant; the implicit requirement of an ad-hoc signature pins the code hash,
// which every compile changes. The tool takes everything as arguments all the same, so a new rule
// never needs a new build.
//
// Usage: karabiner-config-ax-press <bundle-id> <label> [options] [--then <bundle-id> <label> [options]]...
//        karabiner-config-ax-press --serve
//
// (The binary carries the repo's name so the Accessibility list says whose it is; the source and
// this text call it ax-press for short.)
//
// Rules do not launch it. A launch costs two processes -- the re-spawn above -- which is tens of
// milliseconds warm, and was over half a second for a press after half an hour idle on a machine
// short of memory, when the launch checks and the pages behind them had gone cold
// (docs/accessibility-rules.md).
// So launchd keeps one instance running with --serve, from the LaunchAgent the build installs, and
// a rule pipes its arguments to that instance's socket, NUL-terminated, through nc:
//
//   printf '%s\0' <bundle-id> <label> [options] | /usr/bin/nc -U "$HOME/.config/karabiner/scripts/bin/ax-press.sock"
//
// The reply is what a one-shot run would print, then a last line exit=<code>. Requests are handled
// one at a time. launchd starts the server on the first connection and it stays up; a request that
// finds the grant missing makes it exit after replying, because trust is read once per process and
// the next request should start a process that asks again. A one-shot run from a shell still works
// exactly as before, which is what --dump and --dry-run are for.
//
//   --role <AXRole>   role to match (default AXButton)
//   --first           press the first match in document order instead of the last
//   --nth <n>         press the nth match in walk order rather than the first one found (1-based,
//                     default 1). The walk direction still decides what "first" means, so
//                     --first --nth 2 is the second match in document order and --nth 2 alone is
//                     the second from the end. This is what names a control that shares its role,
//                     its label shape and its parent with the one beside it: the Claude app's
//                     folder row carries a local/cloud AXPopUpButton and then the project picker,
//                     both titled with plain varying text, so no label or sibling tells them apart
//                     -- only their order does. Counted per window
//   --dry-run         find and report but do not press
//   --dump            list every element whose label contains <label>, with roles and frames
//   --prompt          ask macOS for Accessibility with the system dialog if it is not granted
//   --log             also append the report line to .claude/ax-press.log in the checkout this
//                     binary lives in (a fixed path, so an argument cannot point it at another file)
//   --budget-ms <n>   stop searching after this long (default 2000)
//   --key <chord>     after the press, post this key chord to the session (a CGEvent, which the
//                     Accessibility grant allows) once the pressed control has left the tree, which
//                     is how a menu item reports that its click was handled: the menu closes. A
//                     control still present when the budget runs out means the key is not posted
//                     and the report says so. <chord> is modifiers and a key joined by +, e.g.
//                     cmd+1 or cmd+shift+return: cmd, shift, option, ctrl; a digit, a letter by its
//                     ANSI (QWERTY) position, return, escape, tab, space, or a macOS virtual key
//                     code as a number. Karabiner's own key events cannot be sequenced behind a
//                     shell_command without a fixed hold, which is what this exists to avoid
//   --else-key <chord>
//                     when no control was found to act on, post this chord instead, in the same
//                     <chord> spelling as --key. This is what lets a rule take a shortcut the app
//                     already uses elsewhere: the control is pressed where it exists, and every
//                     other screen gets the key it would have got had the rule not been there.
//                     Posted before the report so the fall-through is as prompt as the search was
//                     (a populated tree misses in tens of milliseconds), and never under --dry-run,
//                     which is the one path reaching a miss without the Karabiner-launched check
//   --unless-editing  do nothing, and fall through to --else-key, while the app's focused element
//                     is a text control (AXTextField, AXTextArea, AXComboBox, AXSearchField).
//                     A bare key bound to a control is still a character wherever one is being
//                     typed, and a Shortwave settings sidebar row matches just as readily from
//                     inside a label picker's search box as from the sidebar itself -- so the key
//                     was swallowed and the sidebar jumped mid-word. Checked before the walk, from
//                     one AXFocusedUIElement read, so typing costs an attribute read rather than a
//                     tree
//   --wait            keep looking until the control appears or the budget runs out, for a target
//                     that a previous action is still bringing on screen: the Archive item of a
//                     context menu that an AXShowMenu a moment earlier is still opening. Without
//                     it a miss in a populated tree is final; with it the search polls every 25ms
//   --enhanced        also set AXEnhancedUserInterface on the app, the switch VoiceOver uses; only
//                     if AXManualAccessibility, which is set always, does not make the app expose
//                     its web content (Chromium treats the enhanced flag as a screen reader running)
//   --pid <n>         target this process instead of the first one with the bundle id, for when
//                     two instances of the app are running
//   --sibling <text>  only match a control that shares its parent with a control labelled <text>,
//                     which tells one "Copy" button from another: the one beneath a ChatGPT
//                     response sits next to "Good response", a code block's does not
//   --action <AXAction>
//                     perform this action instead of AXPress. AXShowMenu opens the control's
//                     context menu, the same one a right-click would: Chromium implements it for
//                     every web node by dispatching a contextmenu event at the element
//   --label-from <pattern>
//                     fill the {} in <label> from another element on the page. <pattern> is a
//                     label with one {} in it; the first element in document order, of any role,
//                     whose label fits the pattern supplies the text. This is how a rule names a
//                     control that is itself named after something on the page: the Claude app's
//                     "More options for <chat>" button for the chat whose header button reads
//                     "<chat>, rename session"
//   --ancestor <AXRole>[:<n>]
//                     act on the nearest ancestor of the match carrying this role, for a control
//                     whose label lives on a child of it: a SwiftUI sidebar row holds its text in
//                     an AXStaticText inside the row, and the row is the thing that selects.
//                     :<n> takes the nth such ancestor rather than the nearest, and a role of *
//                     counts every level, for a web app whose rows are anonymous AXGroups nested
//                     inside one another and so cannot be told apart by role
//   --within <x0,y0,x1,y1>
//                     only match an element whose frame centre is inside this screen rectangle.
//                     A label repeats outside the region that matters more often than it repeats
//                     inside it: Shortwave names its account avatar "Avatar for <name>" exactly
//                     as it names the ones in its thread rows, and only the rows are in the list
//   --under <AXRole>[:<label>]
//                     search inside the first element with this role, and this label if one is
//                     given, instead of the whole window
//   --click           move the pointer to the centre of the target, click, and put it back, for a
//                     control whose row the tree exposes no action for. Refused unless the target
//                     is inside the window, so a row scrolled out of view cannot land a click on
//                     whatever is behind the app -- pair it with --scroll-first
//   --scroll-first    AXScrollToVisible the target before acting, and re-read its frame, which is
//                     what puts an off-screen row where a click can reach it
//   --scroll-to-end   scroll the last match into view and look again, until the last match stops
//                     changing or the budget runs out, and act on what is last then. A virtualised
//                     list holds only the screenful it draws plus a little, so the end of the list
//                     is not in the tree at all until the list has been scrolled to it: Shortwave
//                     renders 33 thread rows of a mailbox that has far more. Only sound with the
//                     backwards walk, which is what "last" means here, and skipped under --dry-run,
//                     which performs no action at all
//   --dump-all        dump every element, labelled or not; the label argument is then optional.
//                     A filtered dump hides the containers a row hangs off, which are unlabelled
//                     and are exactly what --ancestor and --under have to be aimed at
//   --actions         list each element's actions in a dump, which is the only way to find out
//                     whether a web node answers AXPress before a rule tries it
//   --set <AXAttribute>=<value>
//                     set this attribute on the target instead of performing an action. true and
//                     false are written as booleans, a number as a number -- AXValue on a scroll
//                     bar takes 0 to 1 and is how a list is sent to its end -- anything else as a
//                     string. Setting AXSelected
//                     on an outline row is how a list whose rows have no AXPress is navigated
//                     (Karabiner-Elements' own settings sidebar), and it counts as a press for the
//                     Karabiner-launched check below
//   --then            end this command and start another, which runs only if this one exited 0.
//                     The Claude app's archive rule opens a chat's menu, then presses Archive in it:
//                     one request instead of two helper calls joined with &&, whose exit status a
//                     served request has no way to hand back to the shell
//   --serve           run as the resident server, taking the listening socket from launchd; alone,
//                     with no other arguments
//
// Without --label-from, a {} in <label> is a wildcard: the label matches any non-empty text between
// its prefix and suffix. "#{}" is the Claude app's PR-chip link, whose label is the PR number.
//
// Chromium and Electron do not build their accessibility tree until a client asks for it — and what
// counts as asking is reading the application object's role, which this does first — and they build
// it asynchronously, so the first search after that can see nothing but the window chrome. The
// search therefore retries, briefly, while the window's tree is that small (124ms measured on a
// freshly launched ChatGPT).
//
// Searching works from then on; pressing does not. Chromium ignores AXPress until the app has switched
// to complete accessibility, which Electron does 2s after AXManualAccessibility is set, so the first
// AXPress into each app process waits for that (fullModeDelay) and its report says full_mode_wait_ms.
//
// The label matches AXDescription, AXTitle, AXHelp, AXIdentifier or AXValue exactly (or by its {}
// wildcard), which is where Chromium puts aria-label, visible text, title and id respectively, and
// where SwiftUI puts the text of a static text -- a native label is often nowhere else. --dump
// matches any of them as a case-insensitive substring, to find out which one a control actually
// uses. AXValue also carries the contents of a text field, so a label that could be something the
// user typed wants a --role to keep it off one.
//
// The search walks the focused window's tree from the end of the document backwards, so a control
// near the end of the page, which is where the last response's buttons are, is found after visiting
// a few dozen elements rather than the whole conversation.
//
// A helper that carries its own Accessibility grant is a confused deputy: the disclaim hands the
// grant to whatever runs the binary, and the server answers anyone who can reach its socket, so any
// process running as the user could press any labelled control in any app. The press is therefore
// refused unless Karabiner's console_user_server is among the ancestors of whoever asked -- this
// process for a one-shot run, the process on the other end of the socket for a served request --
// checked by its full path under root-owned /Library. --dump and --dry-run still work from a shell,
// so a label can be found without a rule; a real press cannot.
//
// The report line ends its timing with total_ms, measured from when this process started on the
// request, and, for a request a rule sent, launch_ms: how long before that the shell Karabiner
// spawned for the keypress had started, which is the part of a press no clock in here can see.
// served=true marks a request the server handled.
//
// Exit codes: 0 pressed, 2 not trusted, 3 app not running, 4 no match, 5 press failed, 6 no window,
// 7 no match and the window's tree never grew past its own chrome (accessibility not enabled),
// 8 press refused because Karabiner did not launch this, 9 nothing on the page fits --label-from,
// 10 pressed but the --key chord was not posted (the control never left the tree, or the post failed),
// 64 bad arguments, 71 --serve without a socket from launchd.
// --unless-editing reports found=false with editing=<role> and exits 4, the same as any other
// miss, so --else-key hands the key on exactly as it does when nothing matched. When it does not
// stand down it reports focused=<role> in the stats instead, which is what says whether the app
// is answering AXFocusedUIElement at all -- a backgrounded app answers focused=none.
// --else-key does not change any of these: a miss is still reported as a miss, with the posted
// chord named in the same line, so a rule that falls through every time still says so in the log.

import AppKit
import ApplicationServices
import Foundation

@_silgen_name("responsibility_spawnattrs_setdisclaim")
func responsibility_spawnattrs_setdisclaim(_ attrs: UnsafeMutablePointer<posix_spawnattr_t?>, _ disclaim: Int32) -> Int32

// MARK: - Arguments

struct Options {
  var bundleId = ""
  var label = ""
  var role = "AXButton"
  var first = false
  var nth = 1
  var dryRun = false
  var dump = false
  var prompt = false
  var log = false
  var budgetMs = 2000
  var wait = false
  var key: (code: CGKeyCode, flags: CGEventFlags)?
  var elseKey: (code: CGKeyCode, flags: CGEventFlags)?
  var unlessEditing = false
  var enhanced = false
  var pid: pid_t = 0
  var sibling: String?
  var action = "AXPress"
  var labelFrom: String?
  var ancestor: (role: String, nth: Int)?
  var set: (name: String, value: String)?
  var within: CGRect?
  var under: (role: String, label: String?)?
  var click = false
  var scrollFirst = false
  var scrollToEnd = false
  var dumpAll = false
  var actions = false
}

/// How a command ends early: the exit code a one-shot run exits with, and a served one replies with.
struct Finished: Error {
  let code: Int32
}

/// Where a command's text goes: stdout and stderr for a one-shot run, the reply for a served one.
final class Output {
  let serving: Bool
  var lines: [String] = []

  init(serving: Bool) {
    self.serving = serving
  }

  func line(_ text: String) {
    if serving { lines.append(text) } else { print(text) }
  }

  func error(_ text: String) {
    if serving { lines.append(text) } else { FileHandle.standardError.write("\(text)\n".data(using: .utf8)!) }
  }
}

var output = Output(serving: false)

/// How long after AXManualAccessibility is set an AXPress lands in an Electron app. Chromium drops
/// AXPress on a web control that carries no default action verb and reports success all the same
/// (BrowserAccessibilityManager::DoDefaultAction, crbug.com/348328060), and Blink serializes that verb
/// only in extended-properties mode -- which Electron switches on 2s after the attribute is set,
/// restarting the countdown at every set until it fires (enableScreenReaderCompleteModeAfterDelay in
/// electron_application.mm). Until then the tree is complete enough to search and every press into it
/// is a no-op, which is how the first Cmd+Shift+E after the Claude app launched did nothing. Measured on
/// that app's header menu, idle: a press 2032ms after the set did nothing and one 2056ms after it
/// opened the menu. With all eight cores pegged, presses long after the switch did not open it within
/// 3s either, so load is not covered by this number. docs/accessibility-modes.md has the mechanism,
/// the signals that do not work, and how to reproduce a first press without relaunching the app.
let fullModeDelay: TimeInterval = 2.1

/// When the switch above lands in each app process this helper has set AXManualAccessibility on, keyed
/// by pid and start time so that a reused pid starts over. Only a resident server remembers it; a
/// one-shot run starts empty, so every press it makes waits.
var fullModeDue: [String: Date] = [:]

func usage() throws -> Never {
  output.error("usage: karabiner-config-ax-press <bundle-id> <label> [--role R] [--first] [--nth N] [--dry-run] [--dump] [--dump-all] [--actions] [--prompt] [--log] [--budget-ms N] [--wait] [--key CHORD] [--unless-editing] [--else-key CHORD] [--enhanced] [--pid N] [--sibling TEXT] [--action A] [--click] [--scroll-first] [--scroll-to-end] [--label-from PATTERN] [--ancestor ROLE[:N]] [--within X0,Y0,X1,Y1] [--under ROLE[:LABEL]] [--set ATTR=VALUE] [--then <bundle-id> <label> ...]\n       karabiner-config-ax-press --serve")
  throw Finished(code: 64)
}

func parse(_ argv: [String]) throws -> Options {
  var options = Options()
  var positional: [String] = []
  var i = 0
  while i < argv.count {
    let argument = argv[i]
    switch argument {
    case "--role": i += 1; guard i < argv.count else { try usage() }; options.role = argv[i]
    case "--first": options.first = true
    case "--nth":
      i += 1
      guard i < argv.count, let n = Int(argv[i]), n > 0 else { try usage() }
      options.nth = n
    case "--dry-run": options.dryRun = true
    case "--dump": options.dump = true
    case "--prompt": options.prompt = true
    case "--log": options.log = true
    case "--budget-ms": i += 1; guard i < argv.count, let n = Int(argv[i]) else { try usage() }; options.budgetMs = n
    case "--wait": options.wait = true
    case "--key": i += 1; guard i < argv.count, let chord = parseChord(argv[i]) else { try usage() }; options.key = chord
    case "--unless-editing": options.unlessEditing = true
    case "--else-key": i += 1; guard i < argv.count, let chord = parseChord(argv[i]) else { try usage() }; options.elseKey = chord
    case "--enhanced": options.enhanced = true
    case "--pid": i += 1; guard i < argv.count, let n = Int32(argv[i]) else { try usage() }; options.pid = n
    case "--sibling": i += 1; guard i < argv.count else { try usage() }; options.sibling = argv[i]
    case "--action": i += 1; guard i < argv.count else { try usage() }; options.action = argv[i]
    case "--label-from":
      i += 1
      guard i < argv.count, argv[i].components(separatedBy: "{}").count == 2 else { try usage() }
      options.labelFrom = argv[i]
    case "--ancestor":
      i += 1
      guard i < argv.count else { try usage() }
      // ROLE, or ROLE:N for the nth ancestor with that role. AX roles carry no colon of their own.
      let parts = argv[i].components(separatedBy: ":")
      switch parts.count {
      case 1: options.ancestor = (parts[0], 1)
      case 2: guard let n = Int(parts[1]), n > 0 else { try usage() }; options.ancestor = (parts[0], n)
      default: try usage()
      }
    case "--within":
      i += 1
      let numbers = (i < argv.count ? argv[i] : "").components(separatedBy: ",").compactMap(Double.init)
      guard numbers.count == 4, numbers[2] > numbers[0], numbers[3] > numbers[1] else { try usage() }
      options.within = CGRect(x: numbers[0], y: numbers[1], width: numbers[2] - numbers[0], height: numbers[3] - numbers[1])
    case "--under":
      i += 1
      guard i < argv.count else { try usage() }
      let parts = argv[i].components(separatedBy: ":")
      guard parts.count <= 2, !parts[0].isEmpty else { try usage() }
      options.under = (parts[0], parts.count == 2 ? parts[1] : nil)
    case "--click": options.click = true
    case "--scroll-first": options.scrollFirst = true
    case "--scroll-to-end": options.scrollToEnd = true
    case "--dump-all": options.dump = true; options.dumpAll = true
    case "--actions": options.actions = true
    case "--set":
      i += 1
      let parts = (i < argv.count ? argv[i] : "").components(separatedBy: "=")
      guard parts.count == 2, !parts[0].isEmpty else { try usage() }
      options.set = (parts[0], parts[1])
    default:
      if argument.hasPrefix("--") { try usage() }
      positional.append(argument)
    }
    i += 1
  }
  // --dump-all has nothing to filter by, so it is the one mode that takes no label.
  guard positional.count == 2 || (options.dumpAll && positional.count == 1) else { try usage() }
  options.bundleId = positional[0]
  options.label = positional.count == 2 ? positional[1] : ""
  return options
}

/// The commands in an argument list, split on --then.
func commands(_ arguments: [String]) -> [[String]] {
  arguments.split(separator: "--then", omittingEmptySubsequences: false).map(Array.init)
}

/// ANSI key codes for the names a chord may use. Letters are by physical (QWERTY) position, the
/// same convention as Karabiner's key_code, not by the character a Colemak input source types.
let keyCodes: [String: CGKeyCode] = [
  "a": 0, "s": 1, "d": 2, "f": 3, "h": 4, "g": 5, "z": 6, "x": 7, "c": 8, "v": 9, "b": 11, "q": 12,
  "w": 13, "e": 14, "r": 15, "y": 16, "t": 17, "1": 18, "2": 19, "3": 20, "4": 21, "6": 22, "5": 23,
  "9": 25, "7": 26, "8": 28, "0": 29, "o": 31, "u": 32, "i": 34, "p": 35, "return": 36, "l": 37,
  "j": 38, "k": 40, "n": 45, "m": 46, "tab": 48, "space": 49, "escape": 53,
]

func parseChord(_ spec: String) -> (code: CGKeyCode, flags: CGEventFlags)? {
  var flags: CGEventFlags = []
  var code: CGKeyCode?
  for part in spec.lowercased().split(separator: "+").map(String.init) {
    switch part {
    case "cmd", "command": flags.insert(.maskCommand)
    case "shift": flags.insert(.maskShift)
    case "option", "opt", "alt": flags.insert(.maskAlternate)
    case "ctrl", "control": flags.insert(.maskControl)
    default:
      guard code == nil, let found = keyCodes[part] ?? UInt16(part) else { return nil }
      code = found
    }
  }
  guard let key = code else { return nil }
  return (key, flags)
}

/// Click at a point in screen coordinates: warp there, post the two button events, and put the
/// pointer back where it was. Karabiner can warp and click by itself and does so in every rule
/// that has a fixed coordinate; this exists for the coordinate that is only known once the tree
/// has been read, which no `to` event can be written for in advance.
func postClick(at point: CGPoint) -> Bool {
  let previous = CGEvent(source: nil)?.location
  CGWarpMouseCursorPosition(point)
  guard let down = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: point, mouseButton: .left),
        let up = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: point, mouseButton: .left) else { return false }
  down.post(tap: .cgSessionEventTap)
  up.post(tap: .cgSessionEventTap)
  if let previous { CGWarpMouseCursorPosition(previous) }
  return true
}

/// Post a key chord to the login session. The physical modifiers of the chord that spawned this
/// process may still be down, so the flags are set on the events explicitly rather than inherited.
func postKey(_ chord: (code: CGKeyCode, flags: CGEventFlags)) -> Bool {
  guard let down = CGEvent(keyboardEventSource: nil, virtualKey: chord.code, keyDown: true),
        let up = CGEvent(keyboardEventSource: nil, virtualKey: chord.code, keyDown: false) else { return false }
  down.flags = chord.flags
  up.flags = chord.flags
  down.post(tap: .cgSessionEventTap)
  up.post(tap: .cgSessionEventTap)
  return true
}

// MARK: - Re-spawn with responsibility disclaimed

/// Run this same binary again as its own responsible process and exit with its status. See the
/// header for why: it makes TCC judge the child as ax-press regardless of what launched it.
func respawnDisclaimed() -> Never {
  let path = Bundle.main.executablePath ?? CommandLine.arguments[0]
  var attrs: posix_spawnattr_t? = nil
  posix_spawnattr_init(&attrs)
  defer { posix_spawnattr_destroy(&attrs) }
  let disclaimed = responsibility_spawnattrs_setdisclaim(&attrs, 1)
  if disclaimed != 0 {
    FileHandle.standardError.write("ax-press: responsibility_spawnattrs_setdisclaim failed (\(disclaimed))\n".data(using: .utf8)!)
  }

  let arguments = [path] + Array(CommandLine.arguments.dropFirst()) + ["--worker"]
  var cArguments: [UnsafeMutablePointer<CChar>?] = arguments.map { strdup($0) }
  cArguments.append(nil)
  defer { cArguments.forEach { free($0) } }

  var pid: pid_t = 0
  let spawned = posix_spawn(&pid, path, nil, &attrs, cArguments, environ)
  if spawned != 0 {
    FileHandle.standardError.write("ax-press: posix_spawn failed (\(spawned))\n".data(using: .utf8)!)
    exit(70)
  }
  var status: Int32 = 0
  waitpid(pid, &status, 0)
  // WIFEXITED / WEXITSTATUS as macros are not importable; decode by hand.
  let exited = (status & 0x7f) == 0
  exit(exited ? (status >> 8) & 0xff : 128 + (status & 0x7f))
}

// MARK: - Who launched this

@_silgen_name("proc_pidpath")
func libproc_pidpath(_ pid: Int32, _ buffer: UnsafeMutablePointer<CChar>, _ buffersize: UInt32) -> Int32

/// Karabiner-Elements 15 runs shell_commands from this agent. It lives under root-owned /Library,
/// which is why matching the full path is worth something and matching the name would not be.
let karabinerServer = "/Library/Application Support/org.pqrs/Karabiner-Elements/Karabiner-Console-User-Server.app/Contents/MacOS/Karabiner-Console-User-Server"

func processInfo(of pid: pid_t) -> kinfo_proc? {
  var info = kinfo_proc()
  var size = MemoryLayout<kinfo_proc>.stride
  var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, pid]
  guard sysctl(&mib, UInt32(mib.count), &info, &size, nil, 0) == 0, size > 0 else { return nil }
  return info
}

func parentPid(of pid: pid_t) -> pid_t? {
  processInfo(of: pid)?.kp_eproc.e_ppid
}

func startTime(of pid: pid_t) -> Date? {
  guard let started = processInfo(of: pid)?.kp_proc.p_un.__p_starttime else { return nil }
  return Date(timeIntervalSince1970: Double(started.tv_sec) + Double(started.tv_usec) / 1_000_000)
}

func executablePath(of pid: pid_t) -> String? {
  var buffer = [CChar](repeating: 0, count: 4096)
  let length = libproc_pidpath(pid, &buffer, UInt32(buffer.count))
  return length > 0 ? String(cString: buffer) : nil
}

/// Walk up from `pid`, looking for Karabiner-Console-User-Server. From a one-shot run's parent the
/// chain is the first, undisclaimed stage of this binary, then sh (unless it exec'd its last
/// command), then the server; from the nc that sent a served request it is sh, then the server.
/// Also returns when the process directly under Karabiner started, which is the closest thing to the
/// keypress any process can see.
func launchedByKarabiner(from start: pid_t) -> (Bool, [String], Date?) {
  var chain: [String] = []
  var pid = start
  var below: pid_t = 0
  for _ in 0..<8 where pid > 1 {
    let path = executablePath(of: pid) ?? "?"
    chain.append((path as NSString).lastPathComponent)
    if path == karabinerServer { return (true, chain, below > 1 ? startTime(of: below) : nil) }
    guard let next = parentPid(of: pid) else { break }
    below = pid
    pid = next
  }
  return (false, chain, nil)
}

// MARK: - Accessibility helpers

func attribute(_ element: AXUIElement, _ name: String) -> AnyObject? {
  var value: CFTypeRef?
  let error = AXUIElementCopyAttributeValue(element, name as CFString, &value)
  return error == .success ? value : nil
}

func string(_ element: AXUIElement, _ name: String) -> String? {
  attribute(element, name) as? String
}

func children(_ element: AXUIElement) -> [AXUIElement] {
  (attribute(element, kAXChildrenAttribute) as? [AXUIElement]) ?? []
}

func frame(_ element: AXUIElement) -> CGRect? {
  guard let positionValue = attribute(element, kAXPositionAttribute),
        let sizeValue = attribute(element, kAXSizeAttribute),
        CFGetTypeID(positionValue) == AXValueGetTypeID(),
        CFGetTypeID(sizeValue) == AXValueGetTypeID() else { return nil }
  var position = CGPoint.zero
  var size = CGSize.zero
  AXValueGetValue(positionValue as! AXValue, .cgPoint, &position)
  AXValueGetValue(sizeValue as! AXValue, .cgSize, &size)
  return CGRect(origin: position, size: size)
}

func actionNames(_ element: AXUIElement) -> [String] {
  var names: CFArray?
  guard AXUIElementCopyActionNames(element, &names) == .success else { return [] }
  return (names as? [String]) ?? []
}

let labelAttributes = [kAXDescriptionAttribute, kAXTitleAttribute, kAXHelpAttribute, kAXIdentifierAttribute, kAXValueAttribute]

func labels(_ element: AXUIElement) -> [(String, String)] {
  labelAttributes.compactMap { name in
    guard let value = string(element, name), !value.isEmpty else { return nil }
    return (name, value)
  }
}

func describe(_ element: AXUIElement) -> String {
  let role = string(element, kAXRoleAttribute) ?? "?"
  let subrole = string(element, kAXSubroleAttribute).map { " \($0)" } ?? ""
  let labelText = labels(element).map { "\($0.0)=\"\($0.1)\"" }.joined(separator: " ")
  let frameText = frame(element).map { "frame=(\(Int($0.origin.x)),\(Int($0.origin.y)) \(Int($0.size.width))x\(Int($0.size.height)))" } ?? "frame=?"
  return "\(role)\(subrole) \(labelText) \(frameText)"
}

// MARK: - Search

/// AXUIElement as a set member, so a traversal can tell when a child is one of its own ancestors.
struct ElementKey: Hashable {
  let element: AXUIElement
  static func == (a: ElementKey, b: ElementKey) -> Bool { CFEqual(a.element, b.element) }
  func hash(into hasher: inout Hasher) { hasher.combine(CFHash(element)) }
}

final class Search {
  let options: Options
  /// The label to match: <label> as given, or with its {} filled in by --label-from.
  var label: String
  var deadline: Date
  var visited = 0
  var timedOut = false

  // The tree is not always a tree. A freshly launched ChatGPT answered a walk with an element whose
  // children led back to an ancestor, and the recursion ran until the stack overflowed (SIGSEGV,
  // "excessive recursion"). So the walk keeps its ancestor path and skips any child already on it,
  // with a depth cap as a backstop; the deepest element seen in a real conversation was at 25.
  var path = Set<ElementKey>()
  let maxDepth = 256
  /// Matches passed over so far in the current walk, for --nth. Reset when a walk starts.
  var seen = 0

  init(options: Options) {
    self.options = options
    label = options.label
    deadline = Date().addingTimeInterval(Double(options.budgetMs) / 1000)
  }

  /// True when <label> is a wildcard pattern: it has a {} and nothing fills it.
  var wildcard: Bool { options.labelFrom == nil && label.components(separatedBy: "{}").count == 2 }

  func matches(_ element: AXUIElement) -> Bool {
    guard string(element, kAXRoleAttribute) == options.role else { return false }
    if wildcard {
      guard fill(element, pattern: label) != nil else { return false }
    } else {
      guard labels(element).contains(where: { $0.1 == label }) else { return false }
    }
    // --within: a rectangle is a coarse filter, but it is the one thing that separates a label
    // repeated across a window into the region that matters. The centre, not the origin, so a
    // wide row is judged by where it sits rather than where it starts.
    if let box = options.within {
      guard let elementFrame = frame(element), box.contains(CGPoint(x: elementFrame.midX, y: elementFrame.midY)) else { return false }
    }
    guard let sibling = options.sibling else { return true }
    guard let parent = attribute(element, kAXParentAttribute), CFGetTypeID(parent) == AXUIElementGetTypeID() else { return false }
    return children(parent as! AXUIElement).contains { labels($0).contains { $0.1 == sibling } }
  }

  /// True when this element should be walked into: not an ancestor of itself, not too deep, and
  /// the budget not spent. Registers it on the path; the caller must `leave` it afterwards.
  func enter(_ element: AXUIElement, depth: Int) -> Bool {
    if timedOut || depth > maxDepth { return false }
    let key = ElementKey(element: element)
    if path.contains(key) { return false }
    path.insert(key)
    visited += 1
    if visited % 64 == 0, Date() > deadline { timedOut = true }
    return true
  }

  func leave(_ element: AXUIElement) { path.remove(ElementKey(element: element)) }

  /// Depth-first from the end of the document, so the first hit is the last match in document
  /// order. Children are visited before their parent to keep the traversal an exact reversal of
  /// document order.
  func findLast(_ element: AXUIElement, depth: Int = 0) -> AXUIElement? {
    if depth == 0 { seen = 0 }
    guard enter(element, depth: depth) else { return nil }
    defer { leave(element) }
    for child in children(element).reversed() {
      if let hit = findLast(child, depth: depth + 1) { return hit }
    }
    guard matches(element) else { return nil }
    seen += 1
    return seen >= options.nth ? element : nil
  }

  func findFirst(_ element: AXUIElement, depth: Int = 0) -> AXUIElement? {
    if depth == 0 { seen = 0 }
    guard enter(element, depth: depth) else { return nil }
    defer { leave(element) }
    if matches(element) {
      seen += 1
      if seen >= options.nth { return element }
    }
    for child in children(element) {
      if let hit = findFirst(child, depth: depth + 1) { return hit }
    }
    return nil
  }

  /// The text one of this element's labels contributes to a pattern with one {} in it, or nil.
  func fill(_ element: AXUIElement, pattern: String) -> String? {
    let parts = pattern.components(separatedBy: "{}")
    guard parts.count == 2 else { return nil }
    for (_, value) in labels(element)
    where value.hasPrefix(parts[0]) && value.hasSuffix(parts[1]) && value.count > parts[0].count + parts[1].count {
      return String(value.dropFirst(parts[0].count).dropLast(parts[1].count))
    }
    return nil
  }

  /// Forward walk for --under: the first element in document order with this role, and this label
  /// when one is given. The search then runs inside it rather than the window.
  func findContainer(_ element: AXUIElement, role: String, label: String?, depth: Int = 0) -> AXUIElement? {
    guard enter(element, depth: depth) else { return nil }
    defer { leave(element) }
    if string(element, kAXRoleAttribute) == role, label == nil || labels(element).contains(where: { $0.1 == label }) {
      return element
    }
    for child in children(element) {
      if let hit = findContainer(child, role: role, label: label, depth: depth + 1) { return hit }
    }
    return nil
  }

  /// Forward walk for --label-from: the first element in document order whose label fits.
  func findFill(_ element: AXUIElement, pattern: String, depth: Int = 0) -> String? {
    guard enter(element, depth: depth) else { return nil }
    defer { leave(element) }
    if let text = fill(element, pattern: pattern) { return text }
    for child in children(element) {
      if let text = findFill(child, pattern: pattern, depth: depth + 1) { return text }
    }
    return nil
  }

  /// Forward walk of the whole tree for --dump: every element whose label contains the query.
  func collect(_ element: AXUIElement, depth: Int, roles: inout [String: Int], into hits: inout [(Int, Int, AXUIElement)]) {
    guard enter(element, depth: depth) else { return }
    defer { leave(element) }
    let role = string(element, kAXRoleAttribute) ?? "?"
    roles[role, default: 0] += 1
    let query = options.label.lowercased()
    if options.dumpAll || labels(element).contains(where: { $0.1.lowercased().contains(query) }) {
      hits.append((visited, depth, element))
    }
    for child in children(element) {
      collect(child, depth: depth + 1, roles: &roles, into: &hits)
    }
  }
}

// MARK: - Main

func timestamp() -> String {
  let formatter = ISO8601DateFormatter()
  formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
  return formatter.string(from: Date())
}

/// The one place this binary writes: <checkout>/.claude/ax-press.log, found from its own location
/// (<checkout>/scripts/bin/). Fixed on purpose, so no argument can aim an append at another file.
let logPath: String = {
  let binary = URL(fileURLWithPath: Bundle.main.executablePath ?? CommandLine.arguments[0]).resolvingSymlinksInPath()
  return binary.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent(".claude/ax-press.log").path
}()

func report(_ options: Options, _ line: String) {
  output.line(line)
  guard options.log else { return }
  let path = logPath
  let entry = "\(timestamp()) \(line)\n"
  if let handle = FileHandle(forWritingAtPath: path) {
    handle.seekToEndOfFile()
    handle.write(entry.data(using: .utf8)!)
    handle.closeFile()
  } else {
    FileManager.default.createFile(atPath: path, contents: entry.data(using: .utf8))
  }
}

func millis(since start: Date) -> Int { Int(Date().timeIntervalSince(start) * 1000) }

/// Run one command. `peer` is the process on the other end of the socket for a served request, and
/// nil for a one-shot run, which checks its own ancestry instead. Returns the exit code, or throws it
/// for a command that ends early.
func handle(_ options: Options, peer: pid_t?) throws -> Int32 {
  let start = Date()
  var launchedAt: Date?
  func timing() -> String {
    let launch = launchedAt.map { " launch_ms=\(Int(start.timeIntervalSince($0) * 1000))" } ?? ""
    return "total_ms=\(millis(since: start))\(launch)\(output.serving ? " served=true" : "")"
  }

  let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
  let trusted = AXIsProcessTrustedWithOptions([promptKey: options.prompt] as CFDictionary)
  if !trusted {
    report(options, "trusted=false app=\(options.bundleId) \(timing())")
    throw Finished(code: 2)
  }

  // Reading is allowed from anywhere; pressing only for Karabiner. See the header.
  if !options.dryRun && !options.dump {
    let (fromKarabiner, ancestors, spawned) = launchedByKarabiner(from: peer ?? getppid())
    launchedAt = spawned
    if !fromKarabiner {
      report(options, "trusted=true app=\(options.bundleId) refused=not-launched-by-karabiner ancestors=\(ancestors.joined(separator: "<")) \(timing())")
      throw Finished(code: 8)
    }
  }

  let candidate = options.pid != 0
    ? NSRunningApplication(processIdentifier: options.pid)
    : NSRunningApplication.runningApplications(withBundleIdentifier: options.bundleId).first
  guard let app = candidate else {
    report(options, "trusted=true app=\(options.bundleId) running=false \(timing())")
    throw Finished(code: 3)
  }
  let appElement = AXUIElementCreateApplication(app.processIdentifier)
  AXUIElementSetMessagingTimeout(appElement, 1)
  // Chromium exposes nothing of the page until an assistive client shows up, and on macOS 14+ what
  // counts as showing up is asking for roles (render_widget_host_view_cocoa.mm, "Sonoma
  // accessibility activation refinements"): asking the application object for its role switches on
  // native accessibility, which makes the web contents container appear in the tree, and asking
  // that container (an AXScrollArea) for its role switches on basic web accessibility, after which
  // the page tree fills in asynchronously. The walk below asks every element for its role, so the
  // container is covered once it is visible; the application object it never visits, hence this.
  // AXManualAccessibility and AXEnhancedUserInterface are the switches Electron and VoiceOver use.
  // ChatGPT and Brave refuse both (-25205 / -25208), but the Claude app takes AXManualAccessibility, and the
  // complete mode it brings 2s later is what an AXPress there needs (see fullModeDelay).
  let appRole = string(appElement, kAXRoleAttribute) ?? "?"
  let manual = AXUIElementSetAttributeValue(appElement, "AXManualAccessibility" as CFString, kCFBooleanTrue)
  let enhanced = options.enhanced ? AXUIElementSetAttributeValue(appElement, "AXEnhancedUserInterface" as CFString, kCFBooleanTrue) : nil
  // A set before the switch lands pushes it back; one after it changes nothing.
  let instance = "\(app.processIdentifier)@\(startTime(of: app.processIdentifier)?.timeIntervalSince1970 ?? 0)"
  if manual == .success, (fullModeDue[instance] ?? .distantFuture) > Date() {
    fullModeDue[instance] = Date().addingTimeInterval(fullModeDelay)
  }

  // An app with no window open answers AXFocusedWindow with its own application element (seen
  // when the ChatGPT window was closed while the app kept running), so insist on an actual window.
  var windows: [AXUIElement] = []
  if let focused = attribute(appElement, kAXFocusedWindowAttribute), CFGetTypeID(focused) == AXUIElementGetTypeID() {
    let element = focused as! AXUIElement
    if string(element, kAXRoleAttribute) == kAXWindowRole { windows.append(element) }
  }
  for window in (attribute(appElement, kAXWindowsAttribute) as? [AXUIElement]) ?? [] where !windows.contains(where: { CFEqual($0, window) }) {
    windows.append(window)
  }
  if windows.isEmpty {
    report(options, "trusted=true app=\(options.bundleId) pid=\(app.processIdentifier) windows=0 \(timing())")
    throw Finished(code: 6)
  }

  let search = Search(options: options)

  if options.dump {
    var names: CFArray?
    AXUIElementCopyAttributeNames(appElement, &names)
    output.line("app=\(options.bundleId) pid=\(app.processIdentifier) windows=\(windows.count) app_role=\(appRole)")
    output.line("  set AXManualAccessibility=\(manual.rawValue) AXEnhancedUserInterface=\(enhanced.map { String($0.rawValue) } ?? "not set")")
    output.line("  app attributes: \(((names as? [String]) ?? []).joined(separator: " "))")
    for (index, window) in windows.enumerated() {
      var roles: [String: Int] = [:]
      var hits: [(Int, Int, AXUIElement)] = []
      let windowStart = Date()
      search.collect(window, depth: 0, roles: &roles, into: &hits)
      output.line("window[\(index)] \(describe(window)) title=\"\(string(window, kAXTitleAttribute) ?? "")\"")
      output.line("  elements=\(search.visited) walk_ms=\(millis(since: windowStart))\(search.timedOut ? " TIMED OUT" : "")")
      let roleSummary = roles.sorted { $0.value > $1.value }.prefix(12).map { "\($0.key)=\($0.value)" }.joined(separator: " ")
      output.line("  roles: \(roleSummary)")
      for (order, depth, element) in hits {
        let actions = options.actions ? " actions=[\(actionNames(element).joined(separator: ","))]" : ""
        output.line("  #\(order) depth=\(depth) \(describe(element))\(actions)")
      }
      search.visited = 0
    }
    throw Finished(code: 0)
  }

  // A window whose tree is only its own chrome is a dozen elements; once the web area has been
  // built it is hundreds. Below this, a miss means the tree is not there yet rather than that the
  // control is absent, so the search waits and looks again until the budget runs out. --wait
  // keeps looking after a miss in a populated tree too, for a control that is still on its way.
  let unpopulatedElementCount = 50
  let retryInterval: UInt32 = 25_000

  // --under narrows the walk to one container, which is what keeps a label that repeats elsewhere
  // in the window out of the search; without it the root is the window itself.
  func locate() -> (match: AXUIElement, window: AXUIElement)? {
    for window in windows {
      var root = window
      if let (role, label) = options.under {
        guard let container = search.findContainer(window, role: role, label: label) else { continue }
        root = container
      }
      if let found = options.first ? search.findFirst(root) : search.findLast(root) { return (found, window) }
    }
    return nil
  }

  // --else-key: nothing was found to act on, so hand the chord that spawned this to the app rather
  // than swallowing it, which is what lets a rule bind a shortcut the app already uses on screens
  // where the control is absent. Posted before the report line so the fall-through costs only the
  // search. --dry-run reaches the miss paths without the Karabiner-launched check, so it reports
  // what it would post instead of posting it.
  func elseKey() -> String {
    guard let chord = options.elseKey else { return "" }
    if options.dryRun { return " else_key=skipped-dry-run" }
    return " else_key_posted=\(postKey(chord))"
  }

  // --unless-editing: the label of a control is not the only thing that decides whether a bare key
  // means it. Shortwave's settings sidebar rows are in the tree while a label picker's search box
  // has focus, so a rule bound to "a" pressed the Calendar row instead of typing the letter. The
  // app's focused element says which it is, in one read, before any walk.
  let editableRoles: Set<String> = ["AXTextField", "AXTextArea", "AXComboBox", "AXSearchField"]
  var focusedRole = "none"
  if options.unlessEditing, let focused = attribute(appElement, kAXFocusedUIElementAttribute),
    CFGetTypeID(focused) == AXUIElementGetTypeID() {
    let element = focused as! AXUIElement
    focusedRole = string(element, kAXRoleAttribute) ?? "?"
    if editableRoles.contains(focusedRole) {
      let elseText = elseKey()
      report(options, "trusted=true app=\(options.bundleId) found=false editing=\(focusedRole)\(elseText) app_role=\(appRole) \(timing())")
      throw Finished(code: 4)
    }
  }
  let focusedText = options.unlessEditing ? " focused=\(focusedRole)" : ""

  var hit: AXUIElement?
  var matchWindow: AXUIElement?
  var filled: String?
  var attempts = 0
  while true {
    attempts += 1
    search.visited = 0
    if let pattern = options.labelFrom {
      filled = nil
      for window in windows {
        filled = search.findFill(window, pattern: pattern)
        if filled != nil { break }
      }
      search.label = filled.map { options.label.replacingOccurrences(of: "{}", with: $0) } ?? options.label
    }
    if options.labelFrom == nil || filled != nil, let found = locate() {
      hit = found.match
      matchWindow = found.window
    }
    if hit != nil || (search.visited >= unpopulatedElementCount && !options.wait) || search.timedOut || Date() > search.deadline { break }
    usleep(retryInterval)
  }
  let findMs = millis(since: start)
  let labelText = options.labelFrom == nil ? "" : " label=\"\(search.label)\""
  let stats = "attempts=\(attempts) visited=\(search.visited)\(focusedText)\(search.timedOut ? " timed_out=true" : "")\(labelText) app_role=\(appRole) find_ms=\(findMs)"

  if options.labelFrom != nil && filled == nil {
    let unpopulated = search.visited < unpopulatedElementCount
    let elseText = elseKey()
    report(options, "trusted=true app=\(options.bundleId) found=false filled=false\(unpopulated ? " tree_exposed=false" : "")\(elseText) \(stats) \(timing())")
    throw Finished(code: unpopulated ? 7 : 9)
  }

  guard var match = hit else {
    let unpopulated = search.visited < unpopulatedElementCount
    let elseText = elseKey()
    report(options, "trusted=true app=\(options.bundleId) found=false\(unpopulated ? " tree_exposed=false" : "")\(elseText) \(stats) \(timing())")
    throw Finished(code: unpopulated ? 7 : 4)
  }

  // An AXPress before complete mode lands does nothing (see fullModeDelay), so hold it until then.
  // The switch has the renderer send its whole tree again, so find the target afresh rather than
  // press an element that may have been replaced. Only a press within 2.1s of the helper first
  // reaching an app process waits, and a miss above has already answered, so --else-key never does.
  // AXShowMenu, --set and --click need no default action verb and go straight through.
  var fullModeText = ""
  if !options.dryRun && !options.click && options.set == nil && options.action == "AXPress",
    let due = fullModeDue[instance], due > Date() {
    let wait = due.timeIntervalSinceNow
    Thread.sleep(forTimeInterval: wait)
    search.deadline = search.deadline.addingTimeInterval(wait)
    search.visited = 0
    if let found = locate() {
      match = found.match
      matchWindow = found.window
    }
    fullModeText = " full_mode_wait_ms=\(Int(wait * 1000))"
  }

  // --scroll-to-end: the tree holds the rows a virtualised list has drawn, not the list. Scrolling
  // the last one into view draws the next few, so the end is reached by repeating that until the
  // last match stops changing. The comparison is the whole description, labels and frame together,
  // because two adjacent rows can share an avatar and a settled list also stops moving.
  var scrollText = ""
  if options.scrollToEnd && options.dryRun {
    scrollText = " scroll_to_end=skipped-dry-run"
  } else if options.scrollToEnd {
    var scrolls = 0
    var last = describe(match)
    while Date() < search.deadline {
      guard AXUIElementPerformAction(match, "AXScrollToVisible" as CFString) == .success else { break }
      usleep(30_000)
      search.visited = 0
      guard let next = locate() else { break }
      scrolls += 1
      let description = describe(next.match)
      match = next.match
      matchWindow = next.window
      if description == last { break }
      last = description
    }
    scrollText = " scrolls=\(scrolls)\(Date() >= search.deadline ? " scroll_budget_spent=true" : "")"
  }

  // --ancestor: the match names the target but is not it. Climb by AXParent, which every element
  // answers, to the nearest ancestor with the given role. The cap is a backstop, not a limit worth
  // tuning: the Karabiner sidebar's static text is two levels under its AXRow.
  var acted = match
  var ancestorText = ""
  if let (role, nth) = options.ancestor {
    var climbed: AXUIElement? = nil
    var current = match
    var matched = 0
    // A web app's rows are nested anonymous groups, so the cap has to allow a climb of a dozen
    // levels rather than the two a native row costs.
    for _ in 0..<24 {
      guard let parent = attribute(current, kAXParentAttribute), CFGetTypeID(parent) == AXUIElementGetTypeID() else { break }
      current = parent as! AXUIElement
      guard role == "*" || string(current, kAXRoleAttribute) == role else { continue }
      matched += 1
      if matched == nth { climbed = current; break }
    }
    ancestorText = " ancestor=\(role)\(nth > 1 ? ":\(nth)" : "")"
    guard let found = climbed else {
      let elseText = elseKey()
      report(options, "trusted=true app=\(options.bundleId) found=true\(ancestorText) ancestor_found=false\(elseText) \(stats) \(timing()) \(describe(match))")
      throw Finished(code: 4)
    }
    acted = found
  }
  if options.dryRun {
    report(options, "trusted=true app=\(options.bundleId) found=true pressed=false dry_run=true\(ancestorText) \(stats) \(timing()) \(describe(acted))")
    throw Finished(code: 0)
  }

  // --scroll-first: a row below the fold carries a frame outside the window, which --click refuses
  // to aim at. AXScrollToVisible brings it in, and the frame is read again afterwards so the click
  // and the report both speak of where the target ended up rather than where it was.
  if options.scrollFirst {
    let scrolled = AXUIElementPerformAction(acted, "AXScrollToVisible" as CFString)
    scrollText += " scrolled=\(scrolled == .success)"
  }
  let description = describe(acted)

  // --set writes an attribute instead of performing an action, for a control that offers no action
  // for what it does: an AXRow in a SwiftUI sidebar has only AXShowDefaultUI/AXShowAlternateUI, and
  // setting its AXSelected to true is what selects it.
  let pressed: AXError
  var actionText: String
  if options.click {
    // Refused unless the target is inside the window: an element scrolled out of view has a frame
    // above or below the app, and a click there lands on whatever is behind it.
    let box = frame(acted)
    let windowBox = matchWindow.flatMap(frame)
    let point = box.map { CGPoint(x: $0.midX, y: $0.midY) }
    if let point, let windowBox, windowBox.contains(point) {
      let clicked = postClick(at: point)
      pressed = clicked ? .success : .failure
      actionText = " click=(\(Int(point.x)),\(Int(point.y)))"
    } else {
      pressed = .failure
      actionText = " click_refused=off-window\(point.map { " point=(\(Int($0.x)),\(Int($0.y)))" } ?? "")"
    }
  } else if let (name, value) = options.set {
    let written: CFTypeRef
    switch value {
    case "true": written = kCFBooleanTrue
    case "false": written = kCFBooleanFalse
    default: written = Double(value).map { NSNumber(value: $0) as CFTypeRef } ?? (value as CFString)
    }
    pressed = AXUIElementSetAttributeValue(acted, name as CFString, written)
    actionText = " set=\(name)=\(value)"
  } else {
    pressed = AXUIElementPerformAction(acted, options.action as CFString)
    actionText = options.action == "AXPress" ? "" : " action=\(options.action)"
  }
  actionText += scrollText
  let ok = pressed == .success

  // --key: wait for the pressed control to leave the tree, then post the chord. Re-running the same
  // search is the check; the walk is short while the control is there and full once it is gone.
  var keyText = ""
  var keyOk = true
  if ok, let chord = options.key {
    let pressedAt = Date()
    var gone = false
    while Date() < search.deadline {
      search.visited = 0
      let still = locate()
      if still == nil && !search.timedOut { gone = true; break }
      if search.timedOut { break }
      usleep(retryInterval)
    }
    let goneMs = millis(since: pressedAt)
    if gone {
      keyOk = postKey(chord)
      keyText = " gone_ms=\(goneMs) key_posted=\(keyOk)"
    } else {
      keyOk = false
      keyText = " gone=false gone_ms=\(goneMs) key_posted=false"
    }
  }
  report(options, "trusted=true app=\(options.bundleId) found=true pressed=\(ok)\(ancestorText)\(actionText)\(fullModeText)\(ok ? "" : " ax_error=\(pressed.rawValue)")\(keyText) \(stats) \(timing()) \(description)")
  return ok ? (keyOk ? 0 : 10) : 5
}

/// Run each --then command in turn, stopping at the first that does not exit 0, and return the exit
/// code of the last one run.
func run(_ arguments: [String], peer: pid_t?) -> Int32 {
  var code: Int32 = 0
  for command in commands(arguments) {
    do {
      code = try handle(parse(command), peer: peer)
    } catch let finished as Finished {
      code = finished.code
    } catch {
      output.error("ax-press: \(error)")
      code = 70
    }
    if code != 0 { break }
  }
  return code
}

// MARK: - Server

@_silgen_name("launch_activate_socket")
func launch_activate_socket(_ name: UnsafePointer<CChar>, _ fds: UnsafeMutablePointer<UnsafeMutablePointer<Int32>?>, _ count: UnsafeMutablePointer<Int>) -> Int32

/// Answer requests on the socket launchd opened for the LaunchAgent, one at a time, for as long as
/// launchd keeps the job. See the header for the protocol.
func serve() -> Never {
  signal(SIGPIPE, SIG_IGN)
  var fds: UnsafeMutablePointer<Int32>? = nil
  var count = 0
  let status = launch_activate_socket("Listeners", &fds, &count)
  guard status == 0, let fds, count > 0 else {
    FileHandle.standardError.write("ax-press: --serve takes its socket from launchd (launch_activate_socket: \(status)); scripts/build-ax-press.sh installs the LaunchAgent\n".data(using: .utf8)!)
    exit(71)
  }
  let listener = fds[0]
  free(fds)
  _ = fcntl(listener, F_SETFL, fcntl(listener, F_GETFL) & ~O_NONBLOCK)
  while true {
    let connection = accept(listener, nil, nil)
    guard connection >= 0 else {
      if errno == EINTR || errno == ECONNABORTED { continue }
      exit(71)
    }
    let code = autoreleasepool { respond(on: connection) }
    close(connection)
    // AXIsProcessTrusted answers from what this process learned when it started, so a server
    // running from before a grant would refuse every press until restarted. Exiting hands the next
    // request to a fresh process, which launchd starts on the connection.
    if code == 2 { exit(0) }
  }
}

/// One served request: read its NUL-terminated arguments to end of file, run them, and reply with
/// what a one-shot run would have printed and a last line exit=<code>.
func respond(on connection: Int32) -> Int32 {
  _ = fcntl(connection, F_SETFL, fcntl(connection, F_GETFL) & ~O_NONBLOCK)
  // A client that connects and never finishes must not hold up every request behind it.
  var timeout = timeval(tv_sec: 2, tv_usec: 0)
  setsockopt(connection, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))
  setsockopt(connection, SOL_SOCKET, SO_SNDTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))

  var request: [UInt8] = []
  var buffer = [UInt8](repeating: 0, count: 4096)
  while true {
    let count = read(connection, &buffer, buffer.count)
    if count > 0 {
      request.append(contentsOf: buffer[0..<count])
      if request.count > 65_536 { return 64 }
    } else if count == 0 {
      break
    } else if errno != EINTR {
      return 64
    }
  }
  var arguments = request.split(separator: 0, omittingEmptySubsequences: false).map { String(decoding: $0, as: UTF8.self) }
  if arguments.last == "" { arguments.removeLast() }

  // The process on the other end, whose ancestry decides whether it may press. Unknown means no:
  // pid 0 has no ancestors, so the Karabiner check refuses it.
  var peer: pid_t = 0
  var length = socklen_t(MemoryLayout<pid_t>.size)
  if getsockopt(connection, SOL_LOCAL, LOCAL_PEERPID, &peer, &length) != 0 { peer = 0 }

  output = Output(serving: true)
  defer { output = Output(serving: false) }
  let code = run(arguments, peer: peer)
  let reply = Array(((output.lines + ["exit=\(code)"]).joined(separator: "\n") + "\n").utf8)
  var offset = 0
  while offset < reply.count {
    let written = reply.withUnsafeBytes { write(connection, $0.baseAddress! + offset, reply.count - offset) }
    if written > 0 {
      offset += written
    } else if written < 0 && errno == EINTR {
      continue
    } else {
      break
    }
  }
  return code
}

// MARK: - Main

func main() -> Never {
  var arguments = Array(CommandLine.arguments.dropFirst())
  if arguments == ["--serve"] { serve() }
  if arguments.last == "--worker" {
    arguments.removeLast()
  } else {
    // Refuse bad arguments before paying for a second launch.
    for command in commands(arguments) {
      do { _ = try parse(command) } catch { exit((error as? Finished)?.code ?? 70) }
    }
    respawnDisclaimed()
  }
  exit(run(arguments, peer: nil))
}

main()
