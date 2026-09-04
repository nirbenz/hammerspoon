-- Open the hs.ipc message port so the `hs` CLI can reach this instance
-- (needed for `hs -c "..."`, e.g. scripted reloads).
require("hs.ipc")

-----------------------------------------------
-- Rectangle/Spectacle via Lunette
-----------------------------------------------
-- Window bindings now live in the KEYMAP table at the bottom of this
-- file (single source of truth) and are generated via keymap.toLunette.
-- The spoon is loaded here; bindHotkeys is called after KEYMAP is defined.

hs.loadSpoon("Lunette")

-----------------------------------------------
-- NEW ALT TAB
-----------------------------------------------
-- https://apple.stackexchange.com/questions/402787/reuse-cmdtab-for-hammerspoon-application-switcher

-- switcher = hs.window.switcher.new(hs.window.filter.new():setCurrentSpace(true))
hs.window.filter.forceRefreshOnSpaceChange = true
local wf = hs.window.filter
local altTabFilter = wf.new()
  :setCurrentSpace(true)
  :allowApp("System Settings")

altTabFilter:setAppFilter("Messages", {}) -- allow all windows (incl invisible) if Messenger is flaky
altTabFilter:setSortOrder(wf.sortByFocusedLast)

local switcher = hs.window.switcher.new(altTabFilter)

-- switcher.ui.highlightColor = {0.4,0.4,0.5,0.8} -- gray
switcher.ui.highlightColor = {1.0, 0.64, 0.11, 0.3} -- brighter orange
-- switcher.ui.backgroundColor = {0.3, 0.3, 0.3, 0.5} -- gray
switcher.ui.backgroundColor = {1.0, 0.64, 0.0, 0.3} -- orange
switcher.ui.fontName = 'Menlo'
switcher.ui.textSize = 14
switcher.ui.showTitles = true
switcher.ui.thumbnailSize = 200
switcher.ui.selectedThumbnailSize = 200
switcher.ui.showSelectedThumbnail = false
switcher.ui.showSelectedTitle = false
switcher.ui.showThumbnails = true
switcher.ui.animationDuration = 0

local tabKey = hs.keycodes.map["tab"]

local secureInputApps = {"1Password 7", "1Password", "SecurityAgent", "UserNotificationCenter", "Keychain Access"}

local function mapCmdTab(e)
  if hs.eventtap.isSecureInputEnabled() then
    for _, name in ipairs(secureInputApps) do
      local app = hs.application.get(name)
      if app then
        app:activate()
        hs.alert.show(name .. " is waiting for input", 1.5)
        return false
      end
    end
    hs.alert.show("A password prompt is blocking the switcher", 1.5)
    return false
  end

  local flags = e:getFlags()
  local key = e:getKeyCode()

  if key == tabKey and flags:containExactly{"cmd"} then
    switcher:next()
    return true
  elseif key == tabKey and flags:containExactly{"cmd","shift"} then
    switcher:previous()
    return true
  end

  return false
end

tapCmdTab = hs.eventtap.new({hs.eventtap.event.types.keyDown}, mapCmdTab)
tapCmdTab:start()

-----------------------------------------------
-- WINDOWS AND SPACES
-----------------------------------------------

-- uses with: https://github.com/asmagill/hs._asm.spaces
-- and code from: https://github.com/Hammerspoon/hammerspoon/issues/3111
local hotkey = require "hs.hotkey"
local window = require "hs.window"
local spaces = require "hs.spaces"

-- Enable Spotlight support for better application name matching
hs.application.enableSpotlightForNameSearches(true)


function getGoodFocusedWindow(nofull)
   local win = window.focusedWindow()
   if not win then return end
   
   -- Add app identification info
   local app = win:application()
   if app then
      print(string.format("Application: %s (Bundle ID: %s)", 
                         app:name() or "unknown", 
                         app:bundleID() or "unknown"))
   end
   
   if not win:isStandard() then return end
   if nofull and win:isFullScreen() then return end
   return win
end 

function flashScreen(screen)
   local flash=hs.canvas.new(screen:fullFrame()):appendElements({
    action = "fill",
    fillColor = { alpha = 0.25, red=1},
    type = "rectangle"})
   flash:show()
   hs.timer.doAfter(.15,function () flash:delete() end)
end 

function switchSpace(skip,dir)
   for i=1,skip do
      hs.eventtap.keyStroke({"ctrl","fn"},dir,0) -- "fn" is a bugfix!
   end
end

local hse, hsee, hst = hs.eventtap,hs.eventtap.event,hs.timer

--- This stopped working since Sequoia
function moveWindowOneSpacePreSequoia(dir,switch)
   local win = getGoodFocusedWindow(true)
   if not win then return end
   local screen=win:screen()
   local uuid=screen:getUUID()
   local userSpaces=nil
   for k,v in pairs(spaces.allSpaces()) do
      userSpaces=v
      if k==uuid then break end
   end
   if not userSpaces then return end
   local thisSpace=spaces.windowSpaces(win) -- first space win appears on
   if not thisSpace then
      print("Could not determine window's space")
        return 
    else
        print(string.format("Current space: %s", thisSpace))
        thisSpace=thisSpace[1]
    end

   local last=nil
   local skipSpaces=0
   for _, spc in ipairs(userSpaces) do
      if spaces.spaceType(spc)~="user" then -- skippable space
    skipSpaces=skipSpaces+1
      else
    if last and
       ((dir=="left" and spc==thisSpace) or
        (dir=="right" and last==thisSpace)) then
          local newSpace=(dir=="left" and last or spc)
             print("Attempting to move window to space: " .. newSpace)
          if switch then
            -- spaces.gotoSpace(newSpace)  -- also possible, invokes MC
            switchSpace(skipSpaces+1,dir)
          end
            print(win, newSpace)
            win:focus()  -- Focus the window
            win:raise()    -- Bring to front
            spaces.moveWindowToSpace(win,newSpace)
            -- Silica:focusedWindowToSpace(newSpace)
            -- Drag:focusedWindowToSpace(newSpace)
            win:focus()  -- Focus the window
            win:raise()    -- Bring to front
          return
    end
    last=spc    -- Haven't found it yet...
    skipSpaces=0
      end
   end
   flashScreen(screen)   -- Shouldn't get here, so no space found
end


--- This is the current - ugly - solution using Drag
Drag = hs.loadSpoon("Drag")

function moveWindowOneSpaceDrag(dir, switch)
    local win = getGoodFocusedWindow(true)
    if not win then return end

    local screen = win:screen()
    local allSpaces = spaces.spacesForScreen(screen)
    local thisSpace = spaces.windowSpaces(win)

    if not thisSpace or #thisSpace == 0 then
        print("Could not determine window's space")
        return
    end

    thisSpace = thisSpace[1] -- Get the first space the window is on

    local currentIndex = hs.fnutils.indexOf(allSpaces, thisSpace)
    local targetIndex = (dir == "right") and (currentIndex + 1) or (currentIndex - 1)

    if not allSpaces[targetIndex] then
        flashScreen(screen) -- No available space in this direction
        return
    end

    local targetSpace = allSpaces[targetIndex]

    print("Moving window to space: " .. targetSpace)

    -- Move the window
    Drag:focusedWindowToSpace(targetSpace)

    -- Switch to the space if requested
    if switch then
        switchSpace(1, dir)  -- Using 1 instead of `skipSpaces+1`
    end

    -- Ensure the window is focused
    hs.timer.doAfter(0.4, function()
        win:focus()
        win:raise()
    end)
end



-- Space-move bindings (ctrl+cmd + pageup/pagedown) now live in the
-- KEYMAP table at the bottom of this file.

-----------------------------------------------
-- NEW SPACE AND MOVE WINDOW
-----------------------------------------------

function createSpaceAndMoveWindow()
    local win = getGoodFocusedWindow(true)
    if not win then return end
    
    local screen = win:screen()
    local currentSpace = spaces.activeSpaceOnScreen(screen)

    local allSpaces = spaces.spacesForScreen(screen)
    local currentIndex = hs.fnutils.indexOf(allSpaces, currentSpace)
    
    local success = spaces.addSpaceToScreen(screen, true)
    if not success then return end

    local allSpaces = spaces.spacesForScreen(screen)
    local newSpace = allSpaces[#allSpaces]
    local newSpaceIndex = hs.fnutils.indexOf(allSpaces, newSpace)

    -- We'll reorder the spaces to put the new one after the current one
    -- First, remove the new space from its current position (end of the list)
    -- table.remove(allSpaces, #allSpaces)
    -- -- Then insert it after the current space
    -- table.insert(allSpaces, currentIndex + 1, newSpace)
    -- spaces.setSpaceOrder(table)

    -- now move the window to the new space
    -- spaces.moveWindowToSpace(win, newSpace)
    win:focus()  -- Focus the window
    win:raise()    -- Bring to front
    Drag:focusedWindowToSpace(newSpace)
    -- switchSpace(newSpaceIndex - currentIndex, "right")

    -- make sure the window is focused
    win:focus()
    -- maximize the window
    win:maximize()

end

-- cmd+alt+ctrl+n (new space + move window) now lives in the KEYMAP table.

-----------------------------------------------
-- Finder PgupPgdn Override
-----------------------------------------------

local function remapPageKeys(appName)
    return function(event)
        if hs.application.frontmostApplication():name() == "Finder" then
            if event:getKeyCode() == hs.keycodes.map["pageup"] then
                hs.eventtap.keyStroke({"cmd", "shift"}, "[")  -- Previous Tab
                return true  -- Block original Page Up in Finder
            elseif event:getKeyCode() == hs.keycodes.map["pagedown"] then
                hs.eventtap.keyStroke({"cmd", "shift"}, "]")  -- Next Tab
                return true  -- Block original Page Down in Finder
            end
        end
        return false  -- Let the original key action pass through
    end
end

-- Create an event listener for key presses
local pageKeyListener = hs.eventtap.new({hs.eventtap.event.types.keyDown}, remapPageKeys("Finder"))
pageKeyListener:start()

-----------------------------------------------
-- Control + Mouse Left/Right
-----------------------------------------------

local spaces = require "hs.spaces"
local accumulatedDx = 0  -- Store accumulated mouse movement delta
local lastEventTime = os.clock()  -- Store time of the last event


function mapMouseCtrlMovement(event)
    local flags = event:getFlags()
    local dx = event:getProperty(hs.eventtap.event.properties.mouseEventDeltaX)
    local currentTime = os.clock()  -- Get current time
    local deltaTime = currentTime - lastEventTime  -- Calculate elapsed time
    lastEventTime = currentTime  -- Update time of the last event


    if flags.ctrl then  -- if ctrl key is pressed
        accumulatedDx = accumulatedDx + dx  -- Accumulate mouse movement deltas

        local uuid = hs.mouse.getCurrentScreen()
        local currentSpace = spaces.activeSpaceOnScreen(uuid)
        local userSpaces=nil
        for k,v in pairs(spaces.allSpaces()) do
            userSpaces=v
            if k==uuid then break end
        end

        if accumulatedDx > 100 then  -- Check accumulated delta and elapsed time
            switchSpace(1, "left")
            accumulatedDx = 0  -- Reset accumulated delta after space switch

        elseif accumulatedDx < -100 then  -- Check accumulated delta and elapsed time
            switchSpace(1, "right")
            accumulatedDx = 0  -- Reset accumulated delta after space switch
        end

    accumulatedDx = 0  -- Reset accumulated delta when ctrl is not pressed  
    end

    return true
end

function mapMouseCtrl(event)
    local eventType = event:getType()
    local flags = event:getFlags()
    local buttonNumber = event:getProperty(hs.eventtap.event.properties.mouseEventButtonNumber)
    print("Button pressed: " .. buttonNumber)

    if flags.ctrl then  -- if ctrl key is pressed
        local screen = hs.mouse.getCurrentScreen()
        local currentSpace = spaces.activeSpaceOnScreen(screen)
        local userSpaces = nil
        for _, v in pairs(spaces.allSpaces()) do
            userSpaces = v
        end

        if eventType == hs.eventtap.event.types.otherMouseDown or eventType == hs.eventtap.event.types.otherMouseUp then
            if buttonNumber == 3 then  -- Mouse back button pressed
                switchSpace(1, "left")
            elseif buttonNumber == 4 then  -- Mouse forward button pressed
                switchSpace(1, "right")
            end
        end
    end

    return true
end

mvMouseCtrl = hs.eventtap.new({hs.eventtap.event.types.otherMouseDown, hs.eventtap.event.types.otherMouseUp}, mapMouseCtrl)
-- mvMouseCtrl:start()


-----------------------------------------------
-- Control + Scroll Wheel = Horizontal Scroll
-----------------------------------------------

-- Ctrl + scroll wheel = horizontal scroll
local horizontalScrollTap = hs.eventtap.new(
  {hs.eventtap.event.types.scrollWheel},
  function(event)
    if event:getFlags():containExactly({"ctrl"}) then
      local props = hs.eventtap.event.properties
      local dy = event:getProperty(props.scrollWheelEventDeltaAxis1)
      local dyPt = event:getProperty(props.scrollWheelEventPointDeltaAxis1)
      local dyFix = event:getProperty(props.scrollWheelEventFixedPtDeltaAxis1)

      event:setProperty(props.scrollWheelEventDeltaAxis1, 0)
      event:setProperty(props.scrollWheelEventPointDeltaAxis1, 0)
      event:setProperty(props.scrollWheelEventFixedPtDeltaAxis1, 0)

      event:setProperty(props.scrollWheelEventDeltaAxis2, dy)
      event:setProperty(props.scrollWheelEventPointDeltaAxis2, dyPt)
      event:setProperty(props.scrollWheelEventFixedPtDeltaAxis2, dyFix)

      event:setFlags({})
      return false
    end
    return false
  end
)

-- horizontalScrollTap:start()

-----------------------------------------------
-- KEYMAP: single source of truth
-----------------------------------------------
-- Every shortcut is declared once here. keymap.lua binds the ones
-- it owns (fn/app), generates the Lunette config (lunette=...), and
-- draws the cheatsheet from this same table. doc=true rows are bound
-- by eventtaps above and appear in the cheatsheet for completeness.

local keymap = require("keymap")

KEYMAP = {
  -- Window (Lunette)
  { group = "Window", mods = {"ctrl", "alt"}, key = "left",   label = "Left Half",    lunette = "leftHalf" },
  { group = "Window", mods = {"ctrl", "alt"}, key = "right",  label = "Right Half",   lunette = "rightHalf" },
  { group = "Window", mods = {"ctrl", "alt"}, key = "up",     label = "Top Half",     lunette = "topHalf" },
  { group = "Window", mods = {"ctrl", "alt"}, key = "down",   label = "Bottom Half",  lunette = "bottomHalf" },
  { group = "Window", mods = {"ctrl", "alt"}, key = "u",      label = "Top Left",     lunette = "topLeft" },
  { group = "Window", mods = {"ctrl", "alt"}, key = "i",      label = "Top Right",    lunette = "topRight" },
  { group = "Window", mods = {"ctrl", "alt"}, key = "j",      label = "Bottom Left",  lunette = "bottomLeft" },
  { group = "Window", mods = {"ctrl", "alt"}, key = "k",      label = "Bottom Right", lunette = "bottomRight" },
  { group = "Window", mods = {"ctrl", "alt"}, key = "return", label = "Full Screen",  lunette = "fullScreen" },

  -- Spaces
  { group = "Spaces", mods = {"ctrl", "cmd"}, key = "pagedown", label = "Move window to next space",
    fn = function() moveWindowOneSpaceDrag("right", true) end },
  { group = "Spaces", mods = {"ctrl", "cmd"}, key = "pageup",   label = "Move window to prev space",
    fn = function() moveWindowOneSpaceDrag("left", true) end },
  { group = "Spaces", mods = {"alt", "ctrl"}, key = "n", label = "New space + move window",
    fn = createSpaceAndMoveWindow },

  -- -- Switcher (bound by eventtap above)
  -- { group = "Switcher", mods = {"cmd"},          key = "tab", label = "Next window",     doc = true },
  -- { group = "Switcher", mods = {"cmd", "shift"}, key = "tab", label = "Previous window", doc = true },

  -- -- Finder (bound by eventtap above, Finder only)
  -- { group = "Finder", mods = {}, key = "pageup",   label = "Previous tab", doc = true },
  -- { group = "Finder", mods = {}, key = "pagedown", label = "Next tab",     doc = true },

  -- -- Mouse / scroll (bound by eventtap above)
  -- { group = "Mouse", chordText = "⌃scroll", label = "Horizontal scroll", doc = true },

  -- Help (self-documenting: the cheatsheet toggle lives in the table too)
  { group = "Help", mods = {"cmd", "alt", "ctrl"}, key = "/", label = "Toggle this cheatsheet",
    fn = function() keymap.toggle(KEYMAP) end },
}

keymap.bindAll(KEYMAP)
spoon.Lunette:bindHotkeys(keymap.toLunette(KEYMAP))
