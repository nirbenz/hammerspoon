-----------------------------------------------
-- Rectangle/Spectacle via Lunette
-----------------------------------------------


-- example custom map with `leftHalf` and `rightHalf` reconfigured and the history commands disabled
-- you can have multiple bindings to run a command, as shown in leftHalf

customBindings = {
  leftHalf = {
    {{"cmd", "alt", "ctrl"}, "left"},
  },
  rightHalf = {
    {{"cmd", "alt", "ctrl"}, "right"},
  },
  topHalf = {
    {{"cmd", "alt", "ctrl"}, "up"},
  },
  bottomHalf = {
    {{"cmd", "alt", "ctrl"}, "down"},
  },
  fullScreen = {
    {{"cmd", "alt", "ctrl"}, "M"},
  },
--
  topLeft = false,
  topRight = false,
  bottomLeft = false,
  bottomRight = false,
  center = false,
  nextThird = false,
  prevThird = false,
  enlarge = false,
  shrink = false,
  undo = false,
  redo = false,
  nextDisplay = false,
  prevDisplay = false,
  rightTwoThirds = false,
  leftTwoThirds = false,
}
hs.loadSpoon("Lunette")
spoon.Lunette:bindHotkeys(customBindings)


-----------------------------------------------
-- OLD ALT-TAB
-----------------------------------------------

-- set up your windowfilter
-- include minimized/hidden windows, current Space only
-- filters = {visible=true, currentSpace=true}
-- switcher_space = hs.window.switcher.new(hs.window.filter.new():setCurrentSpace(true):setDefaultFilter(filters))

-- --
-- switcher_space.ui.highlightColor = {0.4,0.4,0.5,0.8}
-- switcher_space.ui.thumbnailSize = 250
-- switcher_space.ui.selectedThumbnailSize = 250
-- switcher_space.ui.backgroundColor = {0.3, 0.3, 0.3, 0.5}
-- switcher_space.ui.fontName = 'Helvetica'
-- switcher_space.ui.textSize = 14
-- switcher_space.ui.showSelectedThumbnail = false
-- switcher_space.ui.showSelectedTitle = false
-- switcher_space.ui.showThumbnails = true
-- switcher_space.ui.animationDuration = 0

-- bind to hotkeys; WARNING: at least one modifier key is required!
-- hs.hotkey.bind('alt', 'tab', nil, function() switcher_space:next() end)
-- hs.hotkey.bind({'alt', 'shift'},'tab', nil, function() switcher_space:previous() end)

-----------------------------------------------
-- NEW ALT TAB
-----------------------------------------------
-- https://apple.stackexchange.com/questions/402787/reuse-cmdtab-for-hammerspoon-application-switcher

switcher = hs.window.switcher.new(hs.window.filter.new():setCurrentSpace(true))

switcher.ui.highlightColor = {0.4,0.4,0.5,0.8}
switcher.ui.thumbnailSize = 250
switcher.ui.selectedThumbnailSize = 250
switcher.ui.backgroundColor = {0.3, 0.3, 0.3, 0.5}
switcher.ui.fontName = 'Helvetica'
switcher.ui.textSize = 10
switcher.ui.showSelectedThumbnail = false
switcher.ui.showSelectedTitle = false
switcher.ui.showThumbnails = true
switcher.ui.animationDuration = 0

function mapCmdTab(event)
    local flags = event:getFlags()
    local chars = event:getCharacters()
    if chars == "\t" and flags:containExactly{'cmd'} then
        switcher:next()
        return true
    elseif chars == string.char(25) and flags:containExactly{'cmd','shift'} then
        switcher:previous()
        return true
    end
end
tapCmdTab = hs.eventtap.new({hs.eventtap.event.types.keyDown}, mapCmdTab)
tapCmdTab:start()

-----------------------------------------------
-- Attempt to fix missing applications.
-----------------------------------------------

local appWatcher = nil

-- Function to handle application events
local function applicationWatcherCallback(appName, eventType, appObject)
    if appName == "Messenger" then -- Check for the Messenger app
        if eventType == hs.application.watcher.activated then -- or use hs.application.watcher.launched based on your need
            -- Attempt to refresh Hammerspoon state for Messenger app
            -- This is a generic approach; you might need to adjust it based on your setup
            local windows = hs.window.filter.new(false):setAppFilter('Messenger')
            if not windows or #windows:getWindows() == 0 then
                print("Messenger windows not registered. Attempting to refresh...")
                -- Here, put your logic to refresh/reinitialize the window switcher or filter
            end
        end
    end
end

-- Start application watcher
appWatcher = hs.application.watcher.new(applicationWatcherCallback)
appWatcher:start()


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
    print("ASDASD")
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
-- WINDOWS AND SPACES
-----------------------------------------------

-- uses with: https://github.com/asmagill/hs._asm.spaces
-- and code from: https://github.com/Hammerspoon/hammerspoon/issues/3111
local hotkey = require "hs.hotkey"
local window = require "hs.window"
local spaces = require "hs.spaces"

function getGoodFocusedWindow(nofull)
   local win = window.focusedWindow()
   if not win or not win:isStandard() then return end
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

function moveWindowOneSpace(dir,switch)
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
   if not thisSpace then return else thisSpace=thisSpace[1] end
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
          if switch then
        -- spaces.gotoSpace(newSpace)  -- also possible, invokes MC
        switchSpace(skipSpaces+1,dir)
          end
          spaces.moveWindowToSpace(win,newSpace)
          win:setLevel(hs.drawing.windowLevels.floating)
          return
    end
    last=spc    -- Haven't found it yet...
    skipSpaces=0
      end
   end
   flashScreen(screen)   -- Shouldn't get here, so no space found
end
mash =      {"ctrl", "cmd"}
-- mashshift = {"ctrl", "cmd", "shift"}

hotkey.bind(mash, "pagedown",nil,
      function() moveWindowOneSpace("right", true) end)
hotkey.bind(mash, "pageup",nil,
      function() moveWindowOneSpace("left", true) end)
-- hotkey.bind(mashshift, "s",nil,
--       function() moveWindowOneSpace("right", false) end)
-- hotkey.bind(mashshift, "a",nil,
--       function() moveWindowOneSpace("left", false) end)

-- alcm = {"⌥", "⌘"}

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

    -- now move the window to the new space
    spaces.moveWindowToSpace(win, newSpace)
    switchSpace(newSpaceIndex - currentIndex, "right")

    -- make sure the window is focused
    win:focus()
    -- maximize the window
    win:maximize()

end

hotkey.bind({"cmd", "alt", "ctrl"}, "n", createSpaceAndMoveWindow)

