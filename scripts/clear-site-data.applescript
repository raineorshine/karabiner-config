-- Clear the current site's data from Chromium DevTools, then return focus to the page.
-- DevTools "Focus page" must be bound to Command-Option-Return.

use scripting additions

set savedClipboard to the clipboard

tell application "System Events"
    keystroke "l" using {command down} -- Focus address bar
    delay 0.1
    keystroke "c" using {command down} -- Copy active tab URL
    delay 0.1
    key code 53 -- Escape: restore previous DevTools focus
end tell

set pageURL to the clipboard as text
set the clipboard to savedClipboard

if not isAllowedLocalhostURL(pageURL) then
    return
end if

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

on isAllowedLocalhostURL(pageURL)
    set localhostPrefix to "https://localhost"
    if pageURL does not start with localhostPrefix then return false
    if length of pageURL is length of localhostPrefix then return true

    set nextCharacter to character ((length of localhostPrefix) + 1) of pageURL
    if nextCharacter is in {"/", "?", "#"} then return true
    if nextCharacter is not ":" then return false

    set portText to ""
    repeat with characterIndex from ((length of localhostPrefix) + 2) to length of pageURL
        set currentCharacter to character characterIndex of pageURL
        if currentCharacter is in {"/", "?", "#"} then exit repeat
        set portText to portText & currentCharacter
    end repeat

    if portText is "" then return false
    repeat with portCharacter in characters of portText
        if "0123456789" does not contain portCharacter then return false
    end repeat

    return true
end isAllowedLocalhostURL
