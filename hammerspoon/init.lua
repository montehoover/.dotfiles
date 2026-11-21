-- Enable the `hs` command-line query channel
require("hs.ipc")
hs.ipc.cliInstall()

-- Start Hammerspoon at login (so a fresh Mac picks this up from the dotfiles)
hs.autoLaunch(true)

-- Cmd+E -> open / focus Finder
hs.hotkey.bind({"cmd"}, "e", function()
    hs.application.launchOrFocus("Finder")
end)

-- Cmd+J -> open / focus the default browser (resolved dynamically)
hs.hotkey.bind({"cmd"}, "j", function()
    hs.application.launchOrFocusByBundleID(hs.urlevent.getDefaultHandler("https"))
end)

-- Ctrl+Option+N -> open / focus Apple Notes.
-- This used to be Rectangle's "Todo Mode" reflow, but Todo Mode silently switches off when its
-- pinned window is closed (which my Cmd+M testing did). Doing it in Hammerspoon is immune to that.
-- reopen ensures a window appears even if Notes was left windowless.
hs.hotkey.bind({"ctrl", "alt"}, "n", function()
    hs.application.launchOrFocus("Notes")
    hs.osascript.applescript('tell application "Notes" to reopen')
end)

-- Cmd+M -> new Apple Note popped into its own floating window.
-- Minimal/fast: reopen self-heals the windowless state (Notes disables "New Note" with no window open),
-- then make a note and pop it into its own window. The main list window is intentionally LEFT OPEN:
-- closing or minimizing it breaks Notes' own Cmd+N (disabled with no main window) and Rectangle's
-- Ctrl+Option+N "reflow todo" (needs a Notes window). No monitor moving; note opens where Notes places it.
hs.hotkey.bind({"cmd"}, "m", function()
    hs.osascript.applescript([[
        tell application "Notes"
            activate
            reopen
        end tell
        delay 0.25
        tell application "System Events"
            tell process "Notes"
                click menu item "New Note" of menu "File" of menu bar 1
                delay 0.2
                click menu item "Open Note in New Window" of menu "Window" of menu bar 1
            end tell
        end tell
    ]])
end)
-- Paste fixed text into whatever app is focused, then restore the previous clipboard.
-- Used for the opsx workflow hotkeys below.
local function pasteText(text)
    local previousContents = hs.pasteboard.getContents()
    hs.pasteboard.setContents(text)
    hs.eventtap.keyStroke({"cmd"}, "v")
    hs.timer.doAfter(0.5, function()
        if previousContents then
            hs.pasteboard.setContents(previousContents)
        else
            hs.pasteboard.clearContents()
        end
    end)
end

-- Ctrl+Option+J -> paste the opsx apply-and-ship workflow prompt
hs.hotkey.bind({"ctrl", "alt"}, "j", function()
    pasteText("/opsx:apply and ask me any questions interactively. Then commit to main and push to github. Then /opsx:archive and openspec sync.")
end)

-- Ctrl+Option+K -> paste the commit-and-archive workflow prompt
hs.hotkey.bind({"ctrl", "alt"}, "k", function()
    pasteText("Commit to main and push to github. /opsx:archive and openspec sync.")
end)

-- Ctrl+Option+L -> paste the prep-for-opsx-apply workflow prompt
hs.hotkey.bind({"ctrl", "alt"}, "l", function()
    pasteText("Get everything ready so I can run opsx apply. Ask interactive questions if necessary.")
end)

-- Ctrl+Option+; -> paste the explain-in-15-word-chunks prompt
hs.hotkey.bind({"ctrl", "alt"}, ";", function()
    pasteText("Explain this in groups of 15 words at a time, always checking to make sure I'm following before printing the next 15 words.")
end)

-- Reload config automatically when this file changes.
-- ~/.hammerspoon is a symlink into ~/.dotfiles, and file watching does not follow
-- symlinks, so watch the real folder it points to.
hs.pathwatcher.new(hs.fs.pathToAbsolute(hs.configdir), function(files)
    for _, file in ipairs(files) do
        if file:sub(-4) == ".lua" then
            hs.reload()
            return
        end
    end
end):start()

hs.alert.show("Hammerspoon config loaded")
