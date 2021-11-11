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
-- Alt-Tab 
-----------------------------------------------

-- set up your windowfilter
-- include minimized/hidden windows, current Space only
switcher_space = hs.window.switcher.new(hs.window.filter.new():setCurrentSpace(true):setDefaultFilter{visible=true})

--
switcher_space.ui.highlightColor = {0.4,0.4,0.5,0.8}
switcher_space.ui.thumbnailSize = 250
switcher_space.ui.selectedThumbnailSize = 250
switcher_space.ui.backgroundColor = {0.3, 0.3, 0.3, 0.5}
switcher_space.ui.fontName = 'Helvetica'
switcher_space.ui.textSize = 14
switcher_space.ui.showSelectedThumbnail = false
switcher_space.ui.showSelectedTitle = false
switcher_space.ui.showThumbnails = true
switcher_space.ui.animationDuration = 0


-- bind to hotkeys; WARNING: at least one modifier key is required!
-- hs.hotkey.bind('alt', 'tab', nil, function() switcher_space:next() end)
-- hs.hotkey.bind({'alt', 'shift'},'tab', nil, function() switcher_space:previous() end)

-----------------------------------------------
-- WINDOWS AND SPACES
-----------------------------------------------

-- uses with: https://github.com/asmagill/hs._asm.undocumented.spaces
-- and code from: https://github.com/Hammerspoon/hammerspoon/issues/235#issuecomment-341576663
local hotkey = require "hs.hotkey"
local window = require "hs.window"
local spaces = require "hs._asm.undocumented.spaces"

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

function switchSpace(skip, dir)
   for i=1,skip do
      hs.eventtap.keyStroke({"ctrl"}, dir)
   end 
end

function moveWindowOneSpace(dir, switch)
   print(dir, switch)
   local win = getGoodFocusedWindow(true)
   if not win then return end
   local screen=win:screen()
   local uuid=screen:spacesUUID()
   local userSpaces=spaces.layout()[uuid]
   local thisSpace=win:spaces() -- first space win appears on
   if not thisSpace then return else thisSpace=thisSpace[1] end
   local last=nil
   local skipSpaces=0
   for _, spc in ipairs(userSpaces) do
      if spaces.spaceType(spc)~=spaces.types.user then -- skippable space
   skipSpaces=skipSpaces+1
      else      -- A good user space, check it
   if last and
      (dir=="left"  and spc==thisSpace) or
      (dir=="right" and last==thisSpace)
   then
      win:spacesMoveTo(dir=="left" and last or spc)
      if switch then
         switchSpace(skipSpaces+1,dir)
         win:focus()
      end
      return
   end
   last=spc  -- Haven't found it yet...
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

-- -- move current window to the space sp
-- function MoveWindowToSpace(sp)
--    local win = hs.window.focusedWindow()      -- current window
--    local uuid = win:screen():spacesUUID()     -- uuid for current screen
--    local spaceID = spaces.layout()[uuid][sp]  -- internal index for sp
--    spaces.moveWindowToSpace(win:id(), spaceID) -- move window to new space
--    spaces.changeToSpace(spaceID)              -- follow window to new space
-- end
-- hs.hotkey.bind(alcm, '1', function() MoveWindowToSpace(1) end)
-- hs.hotkey.bind(alcm, '2', function() MoveWindowToSpace(2) end)
-- hs.hotkey.bind(alcm, '3', function() MoveWindowToSpace(3) end)
-- hs.hotkey.bind(alcm, '4', function() MoveWindowToSpace(4) end)
-- hs.hotkey.bind(alcm, '5', function() MoveWindowToSpace(5) end)