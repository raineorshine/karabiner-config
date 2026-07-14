-- Clear the current site's data from Chromium DevTools, then return focus to the page.
-- DevTools "Focus page" must be bound to Command-Option-Return.

tell application "System Events"
    keystroke "p" using {command down, shift down} -- Open DevTools Command Menu
    delay 0.2

    keystroke "Clear site data"
    delay 0.1
    key code 36 -- Run Clear site data

    key code 36 using {command down, option down} -- DevTools: Focus page
    delay 0.2

    keystroke "r" using {command down} -- Reload page
    delay 1
    key code 53 -- Escape: close tutorial
end tell
