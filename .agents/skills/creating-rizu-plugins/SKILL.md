---
name: creating-rizu-plugins
description: Use when creating or modifying a Rizu plugin (package in userdata/pkg): writing pkg.json, a custom user interface plugin, or a require plugin that monkey patches game modules.
---

# Creating Rizu Plugins

## Overview

A plugin is a package: a directory under `userdata/pkg/` (Git-ignored) with a `pkg.json` at its root. The package manager mounts it, adds it to the Lua `package.path`, and then acts on the `types` declared in `pkg.json`. Code lives in `rizu/pkg/` (see `rizu/pkg/spec.md`).

Packages are discovered from `userdata/pkg/<anything>/`. `pkg.json` may sit directly in that directory or one level deeper (e.g. `userdata/pkg/my_ui/my_ui/pkg.json`). Two packages with the same `name` is an error.

## pkg.json

Every plugin needs one.

```json
{
  "name": "my_ui",
  "display_name": "My UI",
  "desc": "One line about what it does",
  "creator": "You",
  "version": 1,
  "deps": ["other_pkg>=1"],
  "types": {
    "ui": "my_ui.UserInterface"
  }
}
```

- `name` is required and must be unique. It is also the convention for the top-level Lua module/directory, so `require("my_ui.UserInterface")` resolves to `my_ui/UserInterface.lua` inside the package root (a single file `my_ui.lua` works too, with `"ui": "my_ui"`).
- `display_name`, `desc`, `creator`, `version`, `deps` are optional. `deps` entries look like `name>=version`.
- `types` maps a plugin type to the Lua module name to `require`. Unknown types are ignored.

## Plugin types

Only two types are supported.

### `ui`: custom user interface

`types.ui` is a module that returns a class inheriting `rizu.app.UserInterface`. It must override `name` (unique, not `"user_interface"`) and `display_name`. Users pick it in the user-interface setting; if it fails to construct, the game falls back to the default UI and prints the traceback.

```lua
local RizuUserInterface = require("rizu.app.UserInterface")
local IScreenManager = require("gui.IScreenManager")

---@class my_ui.UserInterface : rizu.app.UserInterface
---@operator call: my_ui.UserInterface
local UserInterface = RizuUserInterface + {}

UserInterface.name = "my_ui"
UserInterface.display_name = "My UI"

---@param game sphere.GameController
---@param mount_path string
function UserInterface:new(game, mount_path)
	RizuUserInterface.new(self, game, mount_path, IScreenManager())
end

function UserInterface:load() end
function UserInterface:unload() end

return UserInterface
```

- `self.mount_path` is the package root in the virtual filesystem. Load package assets relative to it (`love.filesystem.read(self.mount_path .. "/file.png")`).
- **Prefer `self.api` (`rizu.api.GameApi`).** It is the stable bridge between the ever-changing core and UIs. Read `rizu/api/README.md`, and the usage comment at the top of each `rizu/api/*.lua` file. `./ui-preview` runs a UI against a fake game, so you can develop without the full game.
- `self.game` (the whole `GameController`) is allowed for things the API does not cover yet, but it changes without notice. **A future update may break a plugin that uses it.** Keep such usage small and isolated so it is easy to fix.
- For retained-mode UIs built on the `gui` module, see the `developing-rizu-ui` skill. Immediate-mode UIs are also fine.
- When the game replaces the UI, it removes all `api` listeners; no need to unsubscribe at the end.

The default UI in `ui/` is the reference implementation.

### `require`: run a module at startup

`types.require` is a module name that the game simply `require`s once the package Lua paths are set up. It does nothing else, so put your side effects at module level. It is the entry point for monkey patching.

```json
{ "name": "my_patch", "version": 1, "types": { "require": "my_patch.init" } }
```

It runs in the main thread **and every worker thread**, so patches also apply in threads that load the module. Do not touch `love.graphics` or main-thread-only state at module level without checking you are on the main thread.

## Monkey patching

Classes are plain tables. `require` the module and replace or wrap a method. Because the module cache is shared, every instance sees the patch.

```lua
local Example = require("rizu.some.Module")

local orig = Example.method

function Example:method(a, b)
	local result = orig(self, a, b)
	-- extra behaviour
	return result
end
```

- Always call the original unless you intentionally replace it, and forward all arguments and returns.
- Patch once. Keep the original in a local; do not re-wrap on reload.
- Patch only what you need. Internal methods are not an API and can be renamed or changed in any update, which breaks the patch. Check the target still exists (`assert(Example.method, "...")`) so a break is loud.
- A `require` package can also be combined with a `ui` package via `deps`, e.g. a UI plus patches it needs.

## Checklist

1. Directory in `userdata/pkg/<name>/` with `pkg.json` (`name`, `types`).
2. Module paths in `types` match files inside the package.
3. UI: inherits `rizu.app.UserInterface`, overrides `name` and `display_name`, uses `self.api` first.
4. Start the game, check the log for `package loaded: <name>` and for `[UserInterfaceManager] Failed to load UI package`.
