// Clear the current site's data from Chromium DevTools, return focus to the page,
// reload it, and close the tutorial.

;(() => {
const systemEvents = Application('System Events')

const keystroke = (key, modifiers = []) => modifiers.length
  ? systemEvents.keystroke(key, { using: modifiers.map(modifier => `${modifier} down`) })
  : systemEvents.keystroke(key)

const browser = ['Brave Browser', 'Google Chrome'].reduce((frontmostBrowser, name) => {
  if (frontmostBrowser) return frontmostBrowser

  try {
    const candidate = Application(name)
    return candidate.running() && candidate.frontmost() ? candidate : null
  }
  catch (_) {
    return null
  }
}, null)

if (!browser || !browser.windows.length) return

const pageUrl = browser.windows[0].activeTab.url()

const isAllowedLocalhostUrl = url =>
  /^https:\/\/localhost(?::\d+)?(?:[/?#]|$)/.test(url)

if (isAllowedLocalhostUrl(pageUrl)) {
  keystroke('p', ['command', 'shift']) // Open DevTools Command Menu
  delay(0.2)

  keystroke('Clear site data')
  delay(0.1)
  systemEvents.keyCode(36) // Run Clear site data

  keystroke('p', ['command', 'shift']) // Open DevTools Command Menu
  delay(0.1)
  keystroke('Focus page')
  delay(0.1)
  systemEvents.keyCode(36) // Run Focus page
  delay(0.2)

  keystroke('r', ['command']) // Reload page
  delay(1)
  systemEvents.keyCode(53) // Escape: close tutorial
}
})()
