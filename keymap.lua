-----------------------------------------------
-- keymap.lua
-- Engine for a single source of truth for shortcuts.
--
-- init.lua defines one KEYMAP table; this module binds it,
-- generates the Lunette config from it, and draws a canvas
-- cheatsheet from the same data. Define each shortcut once.
--
-- Entry shape:
--   { group="Window", mods={"ctrl","alt"}, key="left",
--     label="Left Half",
--     -- one of:
--     fn=function() ... end,   -- bound via hs.hotkey.bind
--     app="Slack",             -- bound to launchOrFocus
--     lunette="leftHalf",      -- bound by the Lunette spoon
--     doc=true,                -- shown only, bound elsewhere (eventtaps)
--     chordText="⌃scroll",     -- override the auto-formatted chord (doc rows)
--   }
-----------------------------------------------

local M = {}

-- macOS display order for modifiers: ⌃⌥⇧⌘
local MOD_SYMBOLS = {
  ctrl = "⌃", control = "⌃",
  alt = "⌥", option = "⌥",
  shift = "⇧",
  cmd = "⌘", command = "⌘",
  fn = "fn",
}
local MOD_ORDER = { ctrl = 1, control = 1, alt = 2, option = 2, shift = 3, cmd = 4, command = 4, fn = 5 }

local KEY_SYMBOLS = {
  left = "←", right = "→", up = "↑", down = "↓",
  ["return"] = "⏎", enter = "⏎",
  pageup = "⇞", pagedown = "⇟",
  tab = "⇥", space = "␣",
  delete = "⌫", forwarddelete = "⌦",
  escape = "⎋", esc = "⎋",
  home = "↖", ["end"] = "↘",
  up_arrow = "↑",
}

local function formatKey(key)
  if not key then return "" end
  local lower = tostring(key):lower()
  return KEY_SYMBOLS[lower] or tostring(key):upper()
end

local function formatMods(mods)
  local ordered = {}
  for _, m in ipairs(mods or {}) do ordered[#ordered + 1] = tostring(m):lower() end
  table.sort(ordered, function(a, b) return (MOD_ORDER[a] or 99) < (MOD_ORDER[b] or 99) end)
  local out = ""
  for _, m in ipairs(ordered) do out = out .. (MOD_SYMBOLS[m] or m) end
  return out
end

function M.formatChord(entry)
  if entry.chordText then return entry.chordText end
  return formatMods(entry.mods) .. formatKey(entry.key)
end

-----------------------------------------------
-- Binding
-----------------------------------------------

-- Bind every entry that owns a real action (fn or app). Entries
-- marked lunette= or doc= are bound elsewhere and skipped here.
function M.bindAll(keymap)
  for _, e in ipairs(keymap) do
    if e.fn then
      hs.hotkey.bind(e.mods, e.key, e.fn)
    elseif e.app then
      hs.hotkey.bind(e.mods, e.key, function() hs.application.launchOrFocus(e.app) end)
    end
  end
end

-- Every Lunette action name, so unlisted actions stay disabled
-- (matches the old hand-written config that set them to false).
local LUNETTE_ACTIONS = {
  "leftHalf", "rightHalf", "topHalf", "bottomHalf",
  "topLeft", "topRight", "bottomLeft", "bottomRight",
  "fullScreen", "center", "nextThird", "prevThird",
  "enlarge", "shrink", "undo", "redo",
  "nextDisplay", "prevDisplay", "rightTwoThirds", "leftTwoThirds",
}

-- Build the table Lunette:bindHotkeys expects from KEYMAP entries
-- tagged with a lunette= action name.
function M.toLunette(keymap)
  local out = {}
  for _, action in ipairs(LUNETTE_ACTIONS) do out[action] = false end
  for _, e in ipairs(keymap) do
    if e.lunette then
      if out[e.lunette] == false then out[e.lunette] = {} end
      table.insert(out[e.lunette], { e.mods, e.key })
    end
  end
  return out
end

-----------------------------------------------
-- Cheatsheet canvas
-----------------------------------------------

local PAD = 30
local COL_GAP = 30
local ROW_H = 26
local GROUP_GAP = 14
local HEADER_H = 24
local TITLE_H = 34
local CHORD_SIZE = 15
local LABEL_SIZE = 15
local HEADER_SIZE = 12
local TITLE_SIZE = 19
local FONT = "Menlo"

local ACCENT = { red = 1.0, green = 0.64, blue = 0.0, alpha = 1.0 }
local WHITE = { white = 1.0, alpha = 0.95 }
local BG = { red = 0.05, green = 0.05, blue = 0.06, alpha = 0.93 }

local current = nil

-- Menlo is monospaced, so estimate width from character count. We avoid
-- hs.drawing.getTextDrawingSize on purpose: calling it corrupts hs.canvas
-- font resolution, after which canvas rejects every string textFont.
-- The estimate runs generous so chords/labels never clip.
local function textWidth(str, size)
  str = tostring(str)
  local n = utf8.len(str) or #str
  return n * size * 0.72
end

-- Group entries by their group field, preserving first-seen order.
local function groupize(keymap)
  local order, byGroup = {}, {}
  for _, e in ipairs(keymap) do
    local g = e.group or "Other"
    if not byGroup[g] then byGroup[g] = {}; order[#order + 1] = g end
    byGroup[g][#byGroup[g] + 1] = e
  end
  return order, byGroup
end

local function buildCanvas(keymap)
  local order, byGroup = groupize(keymap)

  local chordW, labelW = 0, 0
  for _, e in ipairs(keymap) do
    chordW = math.max(chordW, textWidth(M.formatChord(e), CHORD_SIZE))
    labelW = math.max(labelW, textWidth(e.label or "", LABEL_SIZE))
  end

  local contentW = math.max(chordW + COL_GAP + labelW, textWidth("Keyboard Shortcuts", TITLE_SIZE))
  local totalW = contentW + PAD * 2

  local y = PAD + TITLE_H
  for _, g in ipairs(order) do
    y = y + GROUP_GAP + HEADER_H + (#byGroup[g] * ROW_H)
  end
  local totalH = y + PAD

  local sf = hs.screen.mainScreen():frame()
  local canvas = hs.canvas.new({
    x = sf.x + (sf.w - totalW) / 2,
    y = sf.y + (sf.h - totalH) / 2,
    w = totalW, h = totalH,
  })

  local els = {
    {
      type = "rectangle", action = "fill", fillColor = BG,
      roundedRectRadii = { xRadius = 18, yRadius = 18 },
      frame = { x = 0, y = 0, w = totalW, h = totalH },
      trackMouseUp = true,
    },
    {
      type = "text", text = "Keyboard Shortcuts",
      textFont = FONT, textSize = TITLE_SIZE, textColor = WHITE, textAlignment = "center",
      frame = { x = PAD, y = PAD, w = contentW, h = TITLE_H },
    },
  }

  local chordX = PAD
  local labelX = PAD + chordW + COL_GAP
  local cy = PAD + TITLE_H
  for _, g in ipairs(order) do
    cy = cy + GROUP_GAP
    els[#els + 1] = {
      type = "text", text = string.upper(g),
      textFont = FONT, textSize = HEADER_SIZE, textColor = ACCENT,
      frame = { x = PAD, y = cy, w = contentW, h = HEADER_H },
    }
    cy = cy + HEADER_H
    for _, e in ipairs(byGroup[g]) do
      els[#els + 1] = {
        type = "text", text = M.formatChord(e),
        textFont = FONT, textSize = CHORD_SIZE, textColor = ACCENT, textAlignment = "right",
        frame = { x = chordX, y = cy, w = chordW, h = ROW_H },
      }
      els[#els + 1] = {
        type = "text", text = e.label or "",
        textFont = FONT, textSize = LABEL_SIZE, textColor = WHITE,
        frame = { x = labelX, y = cy, w = labelW, h = ROW_H },
      }
      cy = cy + ROW_H
    end
  end

  canvas:appendElements(els)
  canvas:level(hs.canvas.windowLevels.overlay)
  canvas:canvasMouseEvents(true, true)
  canvas:mouseCallback(function() M.hide() end)
  return canvas
end

function M.show(keymap)
  if current then return current end
  current = buildCanvas(keymap)
  current:show()
  return current
end

function M.hide()
  if current then current:delete(); current = nil end
end

function M.toggle(keymap)
  if current then M.hide() else M.show(keymap) end
end

return M
