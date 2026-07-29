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

// vk_none is a no-op key used only to carry a hold_down_milliseconds pause, so hide it from the
// docs rather than rendering it as if it were a key that gets pressed
config.profiles[0].complex_modifications.rules.forEach(rule =>
  rule.manipulators.forEach(manipulator => {
    if (manipulator.to) {
      manipulator.to = manipulator.to.filter(to => to.key_code !== 'vk_none')
    }
  })
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
