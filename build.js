const fs = require('fs')
const path = require('path')
const { toQwerty } = require('qwerty-to-colemak')
const configPath = path.resolve(process.argv[2] || './karabiner.json')
const config = require(configPath)
const karabinerConfigToMarkdown = require('karabiner-config-to-markdown')

const colemakRuleNames = [
  'Chromium DevTools',
  'Launch apps',
  'Quick Chars',
]

const or = fns => x => fns[0](x) || fns.length > 1 && or(fns.slice(1))(x)
const byDescription = description => rule => rule.description.startsWith(description)

// modify config to convert app launcher keys from COLEMAK to QWERTY since they are mnemonics
// do not convert other shortcuts since they are based only on their location on the keyboard
const colemakRules = config.profiles[0].complex_modifications.rules
  .filter(or(colemakRuleNames.map(byDescription)))

colemakRules.forEach(rule =>
  rule.manipulators.forEach(manipulator => {
    manipulator.from.key_code = toQwerty(manipulator.from.key_code) || manipulator.from.key_code
  })
)

const pointingButtons = {
  button1: 'Left Click',
  button2: 'Right Click',
  button3: 'Middle Click',
}

/** Describes a 'to' entry that karabiner-config-to-markdown cannot render (i.e. anything other than key_code and shell_command). Returns null if no description is needed. */
const describeToEntry = entry => {
  const cursor = entry.software_function && entry.software_function.set_mouse_cursor_position
  return cursor ? `Move cursor to (${cursor.x}, ${cursor.y})`
    : entry.pointing_button ? pointingButtons[entry.pointing_button] || entry.pointing_button
    : null
}

// karabiner-config-to-markdown renders only key_code and shell_command entries, so mouse
// entries come out blank; give them a human-readable label in place of the missing key_code
config.profiles[0].complex_modifications.rules.forEach(rule =>
  rule.manipulators.forEach(manipulator =>
    (manipulator.to || []).forEach(entry => {
      const description = describeToEntry(entry)
      if (description) {
        entry.key_code = description
      }
    })
  )
)

/** Simple string templating. Replaces {{key}} with `value` in a template string for each key-value entry in an object. */
const template = (s, o) => {
  let output = s
  for (const [key, value] of Object.entries(o)) {
    output = output.replace(new RegExp(`\\{\\{\\w*${key}\\w*}}`), value)
  }
  return output
}

const readmeTemplate = fs.readFileSync('./readme-template.txt', 'utf-8')
const markdown = karabinerConfigToMarkdown(config)
const output = template(readmeTemplate, { rules: markdown })
console.log(output)
