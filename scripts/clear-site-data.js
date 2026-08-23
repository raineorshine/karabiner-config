// Clear the current site's data from Chromium DevTools, return focus to the page,
// reload it, and close the tutorial.

;(() => {
  const systemEvents = Application('System Events')

  const ENTER = 36
  const ESCAPE = 53

  const keystroke = (key, modifiers = []) =>
    modifiers.length
      ? systemEvents.keystroke(key, {
          using: modifiers.map(modifier => `${modifier} down`),
        })
      : systemEvents.keystroke(key)

  const browser = ['Brave Browser', 'Google Chrome'].reduce((frontmostBrowser, name) => {
    if (frontmostBrowser) return frontmostBrowser

    try {
      const candidate = Application(name)
      return candidate.running() && candidate.frontmost() ? candidate : null
    } catch (_) {
      return null
    }
  }, null)

  if (!browser || !browser.windows.length) return

  const pageUrl = browser.windows[0].activeTab.url()

  // Only clear data on the local dev server and Vercel preview deployments. localhost matches on
  // either scheme, since the dev server runs over http with HTTP=1; Vercel previews are https-only.
  // The host must be followed by a port, path, query, hash, or end-of-string so that lookalikes
  // such as https://vercel.app.example.com do not slip through.
  const ALLOWED_URL =
    /^(?:https?:\/\/localhost|https:\/\/[a-z0-9-]+(?:\.[a-z0-9-]+)*\.vercel\.app)(?::\d+)?(?:[/?#]|$)/i

  if (!ALLOWED_URL.test(pageUrl)) return

  // hit escape until the cursor is null, otherwise Cmd + Shift + P will shadow the native shortcut
  systemEvents.keyCode(ESCAPE)
  systemEvents.keyCode(ESCAPE)
  systemEvents.keyCode(ESCAPE)
  systemEvents.keyCode(ESCAPE)
  systemEvents.keyCode(ESCAPE)

  // Open DevTools Command Menu
  keystroke('p', ['command', 'shift'])
  delay(0.2)

  keystroke('Clear site data')
  delay(0.1)
  systemEvents.keyCode(ENTER)

  keystroke('p', ['command', 'shift']) // Open DevTools Command Menu
  delay(0.1)
  keystroke('Focus page')
  delay(0.1)
  systemEvents.keyCode(ENTER)
  delay(0.2)

  // reload page and wait for welcome modal to appear (which takes a while)
  keystroke('r', ['command'])
  delay(1.2)

  // close tutorial
  systemEvents.keyCode(ESCAPE)
})()
