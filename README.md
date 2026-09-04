# hammerspoon

My Hammerspoon config. Lives at `~/.hammerspoon` as a plain clone of this repo and is pinned as a submodule in my machine migration repo.

## What it does

- Window tiling via Lunette (halves, quarters, full screen) on ctrl+alt plus arrows, u/i/j/k, return.
- Space management: move the focused window to the next or previous space (ctrl+cmd plus pageup/pagedown), or create a new space and move it there (alt+ctrl+n).
- A cmd+tab replacement that switches between windows, not apps, and steps aside when a secure-input prompt (1Password, Keychain) has the keyboard.
- Finder tab switching on pageup/pagedown.
- A keyboard-shortcut cheatsheet on cmd+alt+ctrl+/, drawn from the same table that binds the keys.

## Layout

- `init.lua` is everything: eventtaps, space helpers, and a single `KEYMAP` table that is the source of truth for shortcuts.
- `keymap.lua` binds that table, generates the Lunette config from it, and draws the cheatsheet.
- `Spoons/Lunette.spoon` is Lunette 0.4, vendored.
- `Spoons/Drag.spoon` is vendored from my fork at nirbenz/Drag.spoon. It moves windows between spaces through Mission Control because `hs.spaces.moveWindowToSpace` broke on Sequoia and is still a no-op on macOS 26.3 with Hammerspoon 1.1.1.
- `require "hs.spaces"` resolves to the module bundled with Hammerspoon (1.1.1 ships asmagill's v0.3). Nothing here shadows it.

## Install

```bash
git clone https://github.com/nirbenz/hammerspoon.git ~/.hammerspoon
```

Then reload Hammerspoon. `hs.ipc` is loaded by `init.lua`, so the `hs` CLI works once installed via `hs.ipc.cliInstall()`.

## Archive

The `archive/spaces-sources` branch (tagged `archive-spaces-sources`, not meant to be merged back) keeps what master used to carry for spaces: the 2021 `hs._asm.undocumented.spaces` module, the hs.spaces v0.3 source tree, the vendored `hs/spaces.lua` plus dylibs that shadowed the bundled module, and `init.lua.pre-keymap` from before the KEYMAP refactor. None of it is loaded by the config. That branch's README explains why three spaces modules coexisted and how they differ, including the finding that the vendored v0.3 was a 2022 build which shadowed the Sonoma fix Hammerspoon 1.0.0 already shipped.
