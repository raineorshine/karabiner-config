#!/usr/bin/env node
// Rewrite karabiner.json byte-for-byte the way Karabiner-Elements writes it: keys sorted at every
// level, 4-space indent, every object and array expanded, non-ASCII literal, no trailing newline.
// Karabiner rewrites the live file in this style whenever it saves it, so a file in any other style
// shows up as a whole-file diff in the main checkout and blocks the ship's fast-forward.
// See docs/workflow.md "Editing karabiner.json".
//
// Usage: node scripts/format-karabiner.js [--check] [file]   (file defaults to karabiner.json)
// --check exits 1, writing nothing, when the file is not already in that style.
const fs = require('fs')
const path = require('path')

const args = process.argv.slice(2)
const check = args.includes('--check')
const file = args.find(a => a !== '--check') ?? path.join(__dirname, '..', 'karabiner.json')

const sortKeys = value =>
  Array.isArray(value)
    ? value.map(sortKeys)
    : value && typeof value === 'object'
      ? Object.fromEntries(
          Object.keys(value)
            .sort()
            .map(key => [key, sortKeys(value[key])]),
        )
      : value

const before = fs.readFileSync(file, 'utf8')
const after = JSON.stringify(sortKeys(JSON.parse(before)), null, 4)

if (before === after) process.exit(0)
if (check) {
  console.error(`${file} is not in Karabiner's format; run: node scripts/format-karabiner.js`)
  process.exit(1)
}
fs.writeFileSync(file, after)
