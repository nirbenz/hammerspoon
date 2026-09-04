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
- `Spoons/Drag.spoon` is vendored from my fork at nirbenz/Drag.spoon. It moves windows between spaces through Mission Control because `hs.spaces.moveWindowToSpace` broke on Sequoia.
- `hs/` carries asmagill's hs.spaces v0.3 (`spaces.lua` plus two dylibs). It sits first on the Lua path, so `require "hs.spaces"` loads it instead of the copy bundled with Hammerspoon.

## Install

```bash
git clone https://github.com/nirbenz/hammerspoon.git ~/.hammerspoon
```

Then reload Hammerspoon. `hs.ipc` is loaded by `init.lua`, so the `hs` CLI works once installed via `hs.ipc.cliInstall()`.

## Archive

This is the `archive/spaces-sources` branch, tagged `archive-spaces-sources`. It is a frozen snapshot of master from 2026-09-04, right before the spaces-related files were removed, and is not meant to be merged back. It exists so the old modules stay reachable without cluttering master.

What it keeps that master no longer has:

- `hs/_asm/undocumented/spaces/`: asmagill's `hs._asm.undocumented.spaces`, the 2021 module built on private CoreGraphics space APIs.
- `hs._asm.spaces/`: the source tree of asmagill's `hs._asm.spaces` (hs.spaces v0.3), the module that later became core `hs.spaces`.
- `hs/spaces.lua`, `hs/spaces.docs.json`, `hs/libspaces.dylib`, `hs/libspaces_watcher.dylib` (plus dSYMs): the built v0.3 module, vendored so it sat first on the Lua path and shadowed the copy bundled with Hammerspoon.
- `init.lua.pre-keymap`: `init.lua` from before shortcuts were consolidated into the `KEYMAP` table.

### Why the repo carried three spaces modules

The git history explains it. None of this was a deliberate decision to keep alternatives around; the old module was just never deleted when the next one arrived.

1. Nov 2021 (cb21893). The first commit added `hs/_asm/undocumented/spaces` and `init.lua` did `require "hs._asm.undocumented.spaces"`. Hammerspoon had no spaces module of its own yet, so this was the only way to enumerate spaces and move windows between them.
2. Nov 2024 (7389048, "Updates."). `init.lua` switched to `require "hs.spaces"`, and both `hs._asm.spaces/` (source) and the built `hs/spaces.lua` plus dylibs landed in the same commit. This coincides with `hs.spaces.moveWindowToSpace` breaking on macOS 15 Sequoia; vendoring asmagill's v0.3 directly looks like an attempt to get a working build. It made things worse, not better: the Hammerspoon installed at the time (1.0.0) already carried the Sonoma fix for `moveWindowToSpace`, and the vendored build predates it (see the comparison below). The 2021 module stayed in the tree unused from this point on.
3. Late 2024 onwards. `Spoons/Drag.spoon` took over moving windows between spaces by dragging them through Mission Control, which sidesteps the broken private API. `init.lua` still uses `hs.spaces` for enumeration (`allSpaces`, `spacesForScreen`, `activeSpaceOnScreen`, `addSpaceToScreen`), all of which the bundled module provides.
4. Sep 2026. `hs._asm.spaces/` and `hs/_asm/` were moved here (c56ed43), then `hs/` and `init.lua.pre-keymap` followed (a56f8d7). Master now relies on the `hs.spaces` shipped inside Hammerspoon.app and carries no spaces code of its own.

If a future Hammerspoon release changes `hs.spaces` behaviour, this branch has the exact v0.3 build and the 2021 fallback to compare against.

### What actually differs between the three

Compared on 2026-09-04 against Hammerspoon 1.1.1 (released 2026-02-26) on macOS 26.3. Upstream `extensions/spaces` has not changed since 2024-08-05, so 1.0.0 (2024-08-06), 1.1.0 and 1.1.1 ship identical spaces code. When the three were tried side by side in Nov 2024 the installed Hammerspoon was 1.0.0, so everything below about the shipped module applied then too.

1. `hs._asm.undocumented.spaces` (2021). Pure private API. `internal.so` imports about 35 `CGS*` symbols: CGSManagedDisplaySetCurrentSpace, CGSSpaceCreate and CGSSpaceDestroy, CGSAddWindowsToSpaces and CGSRemoveWindowsFromSpaces, CGSShowSpaces and CGSHideSpaces, plus space level and transform calls. Switching, creating and removing spaces and moving windows all talk to WindowServer directly, with no Mission Control animation. `moveWindowToSpace` is two calls: add the window to the target space, then remove it from the source. asmagill archived the repo in March 2022, calling it superseded, out of date and likely broken.
2. `hs._asm.spaces` v0.3 (written late 2021, merged into Hammerspoon core as `hs.spaces` in 0.9.96, March 2022). A deliberate distillation. The native side shrinks to 7 `SLS*` symbols and does read queries plus a single write, `moveWindowToSpace` via SLSMoveWindowsToManagedSpace. `gotoSpace`, `addSpaceToScreen` and `removeSpace` drive the Dock's Mission Control UI through `hs.axuielement` instead, hence the animation and `MCwaitTime`. The checkout here is pinned at asmagill's f396d3f (2022-04-24), the last commit before his 9d4c339 (2024-05-25, "fix for sonoma 15.4"), which bumped the module to v0.4 and replaced the tarballs. The clone itself dates from 2023-05-07 (reflog of the copy kept in the old `~/.hammerspoon/tmp/`) and was never fetched again, and the files in `hs/` were re-extracted from its v0.3 tarball on 2024-11-05, the day before the "Updates." commit. The vendored `hs/spaces.lua` on this branch is byte-identical to `hs._asm.spaces/src/spaces.lua`, and the vendored `hs/libspaces.dylib` is byte-identical to the one inside `spaces-v0.3-signed.tar.gz`, built 2022-03-18.
3. Shipped `hs.spaces` (1.0.0 through 1.1.1). The same module plus fixes the vendored copy never had: Dock lookup by bundle id (2022-03, the name match used to hit Docker), a nil guard on Mission Control AX children, a `force` argument on `moveWindowToSpace` (2022-10), and commit 63c8239 (2024-08-05, shipped in 1.0.0 the next day) which on macOS 14.5 or newer replaces SLSMoveWindowsToManagedSpace with the yabai workaround, SLSSpaceSetCompatID plus SLSSetWindowListWorkspace. That commit is asmagill's own PR #3638, porting his May 2024 v0.4 fix into core. The shipped `libspaces.dylib` imports those two symbols; the vendored one does not.

So in Nov 2024 asmagill's repo master and Hammerspoon 1.0.0 did carry the same code, but the checkout and tarball installed here were the pre-fix v0.3 from 2022. The copy in `hs/` shadowed a newer build with an older one and was strictly behind the 1.0.0 that was already installed.

Observed behaviour:

- Nov 2024 (Hammerspoon 1.0.0, macOS version not recorded, most likely Sequoia 15). None of the three moved windows reliably. The 2021 module was the only one that did anything, and only for some applications. The trial switched the `require` name between `hs._asm.undocumented.spaces` and `hs.spaces`, which separates the 2021 module from the other two but not those two from each other: with `hs/` present, `require "hs.spaces"` always loaded the vendored v0.3, so the shipped 1.0.0 module was most likely never exercised. That is consistent with its add-then-remove path being a different private call from the managed-space move Apple broke in 14.5. Which windows it still worked for is decided by per-window properties inside WindowServer (collection behaviour, level), not by anything in the module.
- 2026-09-04 (Hammerspoon 1.1.1, macOS 26.3). The shipped `moveWindowToSpace` returns true, with and without `force`, and the window stays on its space. Drag.spoon remains the only working route.
