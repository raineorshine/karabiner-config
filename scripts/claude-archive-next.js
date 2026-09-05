#!/usr/bin/env node
// Archives the current chat in the Claude desktop app and then selects what should be current in
// its place: the next chat in the same project, the previous one when the archived chat was that
// project's last, and the project's + button (New session in <project>) when it was the only one.
//
// Everything is derived from one accessibility dump, which is cheaper than it looks: the walk is
// about 70ms, and the dump is the only way to learn the sidebar's *order*, which the helper's
// label search cannot express. The dump query is "e" because it has to match four different
// labels at once -- the Sidebar group, each project's "New session in <project>" button, each
// row's "More options for <title>" popup, and the header's "<title>, rename session" button,
// which names the current chat -- and every one of them contains an e.
//
// A sidebar row and the header carry the same "More options for <title>" label, so rows are told
// from the header by frame: the sidebar group's own width bounds them. With the sidebar hidden
// there are no rows to order and the script falls back to Cmd+1, the first chat, which is what
// this rule did before it could pick a successor.
//
// Pressing is the helper's job; this script only decides what to press. It is spawned by
// Karabiner, and the helper checks for Karabiner among its ancestors, so its presses are allowed.

const { execFileSync } = require('child_process')

// Absolute, and the live checkout's copy on purpose: the helper binary is gitignored and built
// once, so a worktree has no bin/ of its own, and a rule under test still has to reach a binary
// that carries the Accessibility grant.
const AX = '/Users/raine/.config/karabiner/scripts/bin/karabiner-config-ax-press'
const APP = 'com.anthropic.claudefordesktop'

const ax = (...args) => {
  try {
    return execFileSync(AX, [APP, ...args], { encoding: 'utf8' })
  } catch (error) {
    return (error.stdout || '') + (error.stderr || '')
  }
}

/** The sidebar's chats in document order, the project each belongs to, and the current chat. */
const readSidebar = () => {
  const dump = ax('e', '--dump')
  const sidebar = dump.match(/AXDescription="Sidebar" frame=\(\d+,\d+ (\d+)x/)
  const current = dump.match(/AXDescription="(.*), rename session"/)
  if (!sidebar || !current) return null

  const width = Number(sidebar[1])
  const rows = []
  let project = null
  for (const line of dump.split('\n')) {
    const frame = line.match(/ frame=\((\d+),/)
    if (!frame || Number(frame[1]) >= width) continue
    const header = line.match(/AXButton AXDescription="New session in (.*)" frame=/)
    if (header) {
      project = header[1]
      continue
    }
    const row = line.match(/AXPopUpButton AXDescription="More options for (.*)" frame=/)
    if (row) rows.push({ title: row[1], project })
  }
  return { rows, current: current[1] }
}

/** What to press once the archive has gone through, as helper arguments. */
const successor = () => {
  const sidebar = readSidebar()
  if (!sidebar) return null
  const { rows, current } = sidebar
  const index = rows.findIndex(row => row.title === current)
  if (index < 0) return null

  const project = rows[index].project
  const siblings = rows.filter(row => row.project === project)
  const position = siblings.findIndex(row => row.title === current)
  const next = siblings[position + 1] || siblings[position - 1]
  // The row's own title is prefixed with its status (Idle, Running, Awaiting input), so it is
  // matched as a {} wildcard suffix rather than exactly. --first because the sidebar is at the
  // start of the document, where the helper's default reverse walk would arrive last.
  return next
    ? [`{}${next.title}`, '--role', 'AXButton', '--first', '--log']
    : [`New session in ${project}`, '--role', 'AXButton', '--first', '--log']
}

const target = successor()

// --dry-run resolves the successor and prints it without archiving anything, so the rule can be
// checked from a shell; the helper's own presses stay refused outside Karabiner either way.
if (process.argv.includes('--dry-run')) {
  console.log(target ? target.join(' ') : 'no successor -- falling back to cmd+1')
  console.log(ax(...(target || ['{}x', '--role', 'AXButton', '--first']), '--dry-run').trim())
  process.exit(0)
}

// Archive: press the header's own overflow button, then the Archive item of the dropdown it opens.
// && rather than two spawns, so a dropdown that never opens presses nothing.
const opened = ax('More options for {}', '--role', 'AXPopUpButton', '--label-from', '{}, rename session', '--log')
if (!/found=true/.test(opened)) process.exit(1)
const archived = ax('Archive', '--role', 'AXMenuItem', '--wait', ...(target ? [] : ['--key', 'cmd+1']), '--log')
if (!/found=true/.test(archived)) process.exit(1)

// The successor was resolved before the archive, so the row it names is still the one below the
// archived chat; by now that chat's own row is on its way out of the sidebar.
if (target) ax(...target, '--wait')
