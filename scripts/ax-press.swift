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
// TCC keys that grant to the binary's code signature, and an ad-hoc signed build changes with every
// compile, so rebuilding means granting again in System Settings > Privacy & Security >
// Accessibility. That is why the tool takes everything as arguments: a new rule should never need a
// new build.
//
// Usage: karabiner-config-ax-press <bundle-id> <label> [options]
//
// (The binary carries the repo's name so the Accessibility list says whose it is; the source and
// this text call it ax-press for short.)
//
//   --role <AXRole>   role to match (default AXButton)
//   --first           press the first match in document order instead of the last
//   --dry-run         find and report but do not press
//   --dump            list every element whose label contains <label>, with roles and frames
//   --prompt          ask macOS for Accessibility with the system dialog if it is not granted
//   --log             also append the report line to .claude/ax-press.log in the checkout this
//                     binary lives in (a fixed path, so an argument cannot point it at another file)
//   --budget-ms <n>   stop searching after this long (default 2000)
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
// The label matches AXDescription, AXTitle, AXHelp or AXIdentifier exactly (or by its {} wildcard),
// which is where Chromium puts aria-label, visible text, title and id respectively. --dump matches any of them as a
// case-insensitive substring, to find out which one a control actually uses.
//
// The search walks the focused window's tree from the end of the document backwards, so a control
// near the end of the page, which is where the last response's buttons are, is found after visiting
// a few dozen elements rather than the whole conversation.
//
// A helper that carries its own Accessibility grant is a confused deputy: the disclaim hands the
// grant to whatever runs the binary, so any process running as the user could press any labelled
// control in any app. The press is therefore refused unless Karabiner's console_user_server is
// among this process's ancestors, checked by its full path under root-owned /Library. --dump and
// --dry-run still work from a shell, so a label can be found without a rule; a real press cannot.
//
// Exit codes: 0 pressed, 2 not trusted, 3 app not running, 4 no match, 5 press failed, 6 no window,
// 7 no match and the window's tree never grew past its own chrome (accessibility not enabled),
// 8 press refused because Karabiner did not launch this, 9 nothing on the page fits --label-from.

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
  var dryRun = false
  var dump = false
  var prompt = false
  var log = false
  var budgetMs = 2000
  var enhanced = false
  var pid: pid_t = 0
  var sibling: String?
  var action = "AXPress"
  var labelFrom: String?
  var worker = false
}

func usage() -> Never {
  FileHandle.standardError.write("usage: karabiner-config-ax-press <bundle-id> <label> [--role R] [--first] [--dry-run] [--dump] [--prompt] [--log] [--budget-ms N] [--enhanced] [--pid N] [--sibling TEXT] [--action A] [--label-from PATTERN]\n".data(using: .utf8)!)
  exit(64)
}

func parse(_ argv: [String]) -> Options {
  var options = Options()
  var positional: [String] = []
  var i = 0
  while i < argv.count {
    let argument = argv[i]
    switch argument {
    case "--role": i += 1; guard i < argv.count else { usage() }; options.role = argv[i]
    case "--first": options.first = true
    case "--dry-run": options.dryRun = true
    case "--dump": options.dump = true
    case "--prompt": options.prompt = true
    case "--log": options.log = true
    case "--budget-ms": i += 1; guard i < argv.count, let n = Int(argv[i]) else { usage() }; options.budgetMs = n
    case "--enhanced": options.enhanced = true
    case "--pid": i += 1; guard i < argv.count, let n = Int32(argv[i]) else { usage() }; options.pid = n
    case "--sibling": i += 1; guard i < argv.count else { usage() }; options.sibling = argv[i]
    case "--action": i += 1; guard i < argv.count else { usage() }; options.action = argv[i]
    case "--label-from":
      i += 1
      guard i < argv.count, argv[i].components(separatedBy: "{}").count == 2 else { usage() }
      options.labelFrom = argv[i]
    case "--worker": options.worker = true
    default:
      if argument.hasPrefix("--") { usage() }
      positional.append(argument)
    }
    i += 1
  }
  guard positional.count == 2 else { usage() }
  options.bundleId = positional[0]
  options.label = positional[1]
  return options
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

func parentPid(of pid: pid_t) -> pid_t? {
  var info = kinfo_proc()
  var size = MemoryLayout<kinfo_proc>.stride
  var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, pid]
  guard sysctl(&mib, UInt32(mib.count), &info, &size, nil, 0) == 0, size > 0 else { return nil }
  return info.kp_eproc.e_ppid
}

func executablePath(of pid: pid_t) -> String? {
  var buffer = [CChar](repeating: 0, count: 4096)
  let length = libproc_pidpath(pid, &buffer, UInt32(buffer.count))
  return length > 0 ? String(cString: buffer) : nil
}

/// Walk up from the parent. Under Karabiner the chain is: the first, undisclaimed stage of this
/// binary, then sh (unless it exec'd its last command), then Karabiner-Console-User-Server.
func launchedByKarabiner() -> (Bool, [String]) {
  var chain: [String] = []
  var pid = getppid()
  for _ in 0..<8 where pid > 1 {
    let path = executablePath(of: pid) ?? "?"
    chain.append((path as NSString).lastPathComponent)
    if path == karabinerServer { return (true, chain) }
    guard let next = parentPid(of: pid) else { break }
    pid = next
  }
  return (false, chain)
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

let labelAttributes = [kAXDescriptionAttribute, kAXTitleAttribute, kAXHelpAttribute, kAXIdentifierAttribute]

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
  let deadline: Date
  var visited = 0
  var timedOut = false

  // The tree is not always a tree. A freshly launched ChatGPT answered a walk with an element whose
  // children led back to an ancestor, and the recursion ran until the stack overflowed (SIGSEGV,
  // "excessive recursion"). So the walk keeps its ancestor path and skips any child already on it,
  // with a depth cap as a backstop; the deepest element seen in a real conversation was at 25.
  var path = Set<ElementKey>()
  let maxDepth = 256

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
    guard enter(element, depth: depth) else { return nil }
    defer { leave(element) }
    for child in children(element).reversed() {
      if let hit = findLast(child, depth: depth + 1) { return hit }
    }
    return matches(element) ? element : nil
  }

  func findFirst(_ element: AXUIElement, depth: Int = 0) -> AXUIElement? {
    guard enter(element, depth: depth) else { return nil }
    defer { leave(element) }
    if matches(element) { return element }
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
    if labels(element).contains(where: { $0.1.lowercased().contains(query) }) {
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
  print(line)
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

func main() {
  let options = parse(Array(CommandLine.arguments.dropFirst()))
  if !options.worker { respawnDisclaimed() }

  let start = Date()
  let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
  let trusted = AXIsProcessTrustedWithOptions([promptKey: options.prompt] as CFDictionary)
  if !trusted {
    report(options, "trusted=false app=\(options.bundleId) total_ms=\(millis(since: start))")
    exit(2)
  }

  // Reading is allowed from anywhere; pressing only for Karabiner. See the header.
  if !options.dryRun && !options.dump {
    let (fromKarabiner, ancestors) = launchedByKarabiner()
    if !fromKarabiner {
      report(options, "trusted=true app=\(options.bundleId) refused=not-launched-by-karabiner ancestors=\(ancestors.joined(separator: "<")) total_ms=\(millis(since: start))")
      exit(8)
    }
  }

  let candidate = options.pid != 0
    ? NSRunningApplication(processIdentifier: options.pid)
    : NSRunningApplication.runningApplications(withBundleIdentifier: options.bundleId).first
  guard let app = candidate else {
    report(options, "trusted=true app=\(options.bundleId) running=false total_ms=\(millis(since: start))")
    exit(3)
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
  // AXManualAccessibility and AXEnhancedUserInterface are the switches an older Electron and
  // VoiceOver use; both are refused here (-25205 / -25208) but cost nothing to try.
  let appRole = string(appElement, kAXRoleAttribute) ?? "?"
  let manual = AXUIElementSetAttributeValue(appElement, "AXManualAccessibility" as CFString, kCFBooleanTrue)
  let enhanced = options.enhanced ? AXUIElementSetAttributeValue(appElement, "AXEnhancedUserInterface" as CFString, kCFBooleanTrue) : nil

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
    report(options, "trusted=true app=\(options.bundleId) pid=\(app.processIdentifier) windows=0 total_ms=\(millis(since: start))")
    exit(6)
  }

  let search = Search(options: options)

  if options.dump {
    var names: CFArray?
    AXUIElementCopyAttributeNames(appElement, &names)
    print("app=\(options.bundleId) pid=\(app.processIdentifier) windows=\(windows.count) app_role=\(appRole)")
    print("  set AXManualAccessibility=\(manual.rawValue) AXEnhancedUserInterface=\(enhanced.map { String($0.rawValue) } ?? "not set")")
    print("  app attributes: \(((names as? [String]) ?? []).joined(separator: " "))")
    for (index, window) in windows.enumerated() {
      var roles: [String: Int] = [:]
      var hits: [(Int, Int, AXUIElement)] = []
      let windowStart = Date()
      search.collect(window, depth: 0, roles: &roles, into: &hits)
      print("window[\(index)] \(describe(window)) title=\"\(string(window, kAXTitleAttribute) ?? "")\"")
      print("  elements=\(search.visited) walk_ms=\(millis(since: windowStart))\(search.timedOut ? " TIMED OUT" : "")")
      let roleSummary = roles.sorted { $0.value > $1.value }.prefix(12).map { "\($0.key)=\($0.value)" }.joined(separator: " ")
      print("  roles: \(roleSummary)")
      for (order, depth, element) in hits {
        print("  #\(order) depth=\(depth) \(describe(element))")
      }
      search.visited = 0
    }
    exit(0)
  }

  // A window whose tree is only its own chrome is a dozen elements; once the web area has been
  // built it is hundreds. Below this, a miss means the tree is not there yet rather than that the
  // control is absent, so the search waits and looks again until the budget runs out.
  let unpopulatedElementCount = 50
  let retryInterval: UInt32 = 25_000

  var hit: AXUIElement?
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
    if options.labelFrom == nil || filled != nil {
      for window in windows {
        hit = options.first ? search.findFirst(window) : search.findLast(window)
        if hit != nil { break }
      }
    }
    if hit != nil || search.visited >= unpopulatedElementCount || search.timedOut || Date() > search.deadline { break }
    usleep(retryInterval)
  }
  let findMs = millis(since: start)
  let labelText = options.labelFrom == nil ? "" : " label=\"\(search.label)\""
  let stats = "attempts=\(attempts) visited=\(search.visited)\(search.timedOut ? " timed_out=true" : "")\(labelText) app_role=\(appRole) find_ms=\(findMs)"

  if options.labelFrom != nil && filled == nil {
    let unpopulated = search.visited < unpopulatedElementCount
    report(options, "trusted=true app=\(options.bundleId) found=false filled=false\(unpopulated ? " tree_exposed=false" : "") \(stats) total_ms=\(millis(since: start))")
    exit(unpopulated ? 7 : 9)
  }

  guard let target = hit else {
    let unpopulated = search.visited < unpopulatedElementCount
    report(options, "trusted=true app=\(options.bundleId) found=false\(unpopulated ? " tree_exposed=false" : "") \(stats) total_ms=\(millis(since: start))")
    exit(unpopulated ? 7 : 4)
  }

  let description = describe(target)
  if options.dryRun {
    report(options, "trusted=true app=\(options.bundleId) found=true pressed=false dry_run=true \(stats) total_ms=\(millis(since: start)) \(description)")
    exit(0)
  }

  let pressed = AXUIElementPerformAction(target, options.action as CFString)
  let ok = pressed == .success
  let actionText = options.action == "AXPress" ? "" : " action=\(options.action)"
  report(options, "trusted=true app=\(options.bundleId) found=true pressed=\(ok)\(actionText)\(ok ? "" : " ax_error=\(pressed.rawValue)") \(stats) total_ms=\(millis(since: start)) \(description)")
  exit(ok ? 0 : 5)
}

main()
