# Project Context

Rizu is a rhythm game. Mania (vertical scrolling, VSRG) is the complete gamemode. osu!, taiko, catch and SDVX are playable but experimental: no scoring, no result screen, no server submission, local replays only.

## Runtime And Libraries

- LuaJIT
- LÖVE 12
- BASS for audio
- FFmpeg for some image decoding
- Extensive FFI usage

## Repository Structure

1. `rizu/` contains the modern game code.
2. `sphere/` contains legacy code. Some of it is still in use.
3. `ui/` contains the modern UI built on the `gui` module.
4. `gui/` is the GUI framework.
5. `aqua/` is a collection of Lua and C libraries.
6. `chart/` reads supported Chart formats such as `.osu`, `.sm`, and `.bms`.
7. `sea/` is the game server. It accepts and validates replays, and uses HTML, CSS, ETLua, and some JavaScript for its UI.
8. `bancho/` is the server for regular osu!stable. The project plans to connect osu!stable to the game server through a bridge.

## Core game classes and modules

Entry point: `main.lua` - starts the updater and then creates Loop and GameController.
GameController: `sphere/controllers/GameController.lua` - a huge class that contains in self all controllers and models, calls load(), update(dt), draw() and receive(love_event) on them. Treat this as "backend".
Game API: `rizu/api/*` - Exposes a stable API for UI. A bridge between always changing core game and UI.
User Interface: `ui/UserInterface.lua` - Default user interface. Aimed to be separate from the game. Treat this as "frontend". People can make custom user interfaces using plugins.
Gameplay skins: `/rizu/skin` - Placeholder base, osu! and Lua gameplay skins. They take notes from the engine and draw them to the screen. Also have their own HUD elements, separate from regular UI. Needs to work with any weird custom UI, doesn't no uses "gui" module.

## Classes And Annotations

Use the project class library with `local class = require("class")`.

```lua
local class = require("class")

---@class example.Base
---@operator call: example.Base
local Base = class()

function Base:new(value)
	self.value = value
end

---@class example.Child : example.Base
---@operator call: example.Child
local Child = Base + {}

function Child:new(value)
	Base.new(self, value)
end

local child = Child(42)
assert(Child * child) -- instance check
assert(Base / Child) -- class inheritance check
```

- Create a base class with `class()`.
- Inherit with `Parent + {}`. Multiple class tables can be combined with `ParentA + ParentB` when needed.
- Instantiate by calling the class: `ClassName(...)`. This allocates the instance and calls `ClassName:new(...)` when defined.
- Base constructors are not called automatically. Call them explicitly with `Parent.new(self, ...)`.
- Use `Class * value` to test whether a value is an instance of that class or a subclass.
- Use `Parent / Child` to test whether `Child` is `Parent` or inherits from it.

Use LuaLS/EmmyLua annotations for classes, fields, parameters, return values, aliases, and callable classes. The annotation class name follows the file path from the repository root: replace `/` with `.`, and remove `.lua`.

For example, `gui/layout/FlowContainer.lua` defines:

```lua
---@class gui.layout.FlowContainer : gui.View
---@operator call: gui.layout.FlowContainer
local FlowContainer = View + {}
```

Keep class names aligned with their paths. Nested supporting types may append a suffix, such as `gui.layout.FlowContainer.Config`.

Modules located under `aqua/` are exposed as top-level modules. Require them without the `aqua.` prefix:

```lua
local class = require("class") -- correct
local class = require("aqua.class") -- incorrect
```

## Tests

- Run `./test-love` for modules that require LÖVE.
- Run `./test` for simple LuaJIT modules that do not depend on LÖVE.
- Only files ending in `_test.lua` are tests.

## Lua Language Server Diagnostics

Use `luajit scripts/luals.lua check <file.lua>` to check LuaLS errors and warnings for a specific project file. Run it with the system `luajit`, not `./luajit`, whose memory limit is too small for LuaLS. The path can be relative to the current directory or the project, or absolute. Use `--level Hint --format json` to include all severities in machine-readable output. Exit codes are `0` for no diagnostics, `1` when diagnostics are found, and `2` for usage or setup errors.

If LuaLS is missing, install the pinned release into `build/lua-language-server` with `luajit scripts/luals.lua install` (`--version latest` for the newest release, `--source` to build it, which needs ninja and a C++17 compiler). An executable in `LUA_LANGUAGE_SERVER` or `--server` takes precedence, and `PATH` is the last resort.

A check without the daemon starts LuaLS for the whole workspace and takes about 10 seconds. For repeated checks, start the daemon with `luajit scripts/luals.lua start`. It returns once LuaLS has diagnosed the whole workspace, about a minute, and checks then take a fraction of a second; `check` uses the daemon automatically. Use `--server-mode required` to require it or `--server-mode off` to force a one-shot check. The daemon picks up edited, added and removed files before each check. Stop it with `luajit scripts/luals.lua stop`; `status` reports whether it runs. All commands accept `--project <directory>` for another LuaLS-configured project.

## Before you write

Read the task and the code it touches. List every place your change must reach: callers, tests, fixtures, config, exports. Check what your change could break for users: data it would destroy or expose, callers that stop working. That is scope. Extra features are not.

## The smallest complete change

Take the first option that fully works:

1. Does it need to exist? Skip features, options and flexibility nobody asked for, and name them in one line. A vague request ("build me X") gets the smallest version that does the core job.
2. Already in this codebase (a helper, component, service, pattern)? Use it the way the surrounding code does.
3. Standard library or a platform feature? Use it, unless the project has its own. A house component beats a native widget.
4. An installed dependency? Use it. Never add a dependency for a few lines.
5. Can it be one line a reader gets at a glance? One line.
6. Otherwise: the minimum code that works.

- Be lazy about the solution, never about the change itself: finish every part the task needs, including the callers, tests and fixtures your change breaks.
- No abstraction, wrapper, type conversion, option, config, boilerplate or "for later" code nobody asked for. Keep values in the form the platform already gives you. Deletion beats addition. Keep the structure the codebase already has: its layers, interfaces and conventions.
- The shortest working diff wins, once you know everything it must touch. A one-liner that needs decoding is not short.
- Comment only the why the code cannot show, in one line.
- Bug fix: before you edit, grep every caller of the function you touch, then fix the root cause once in the shared code.
- Code you move or merge keeps its error handling and validation.
- Between options of equal size, take the one that is correct on edge cases.
- Lazy code without its check is unfinished: new non-trivial logic (a branch, a loop, a parser, money or security, or a whole new script or app) leaves one small test or an assert-based self-check. Trivial changes need none.
- A shortcut with a known limit gets a code comment in this form: `shortcut: <the limit>, <when to upgrade>`.

Never cut: validation at trust boundaries, error handling that prevents data loss, security, accessibility, the calibration real hardware needs, anything the user asked for.
