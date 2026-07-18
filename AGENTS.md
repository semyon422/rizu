# AGENTS.md

## Purpose

This is the repository-wide source of truth for AI coding assistants.

Tool-specific instruction files (for example `GEMINI.md`, `CLAUDE.md`, `.cursorrules`) should defer to this file. If another instruction file conflicts with this one, follow `AGENTS.md` unless explicitly told otherwise by the user in the current task.

## Quick Checklist

Before editing:
1. Read this file and then scan nearby module docs, especially local `spec.md` files.
2. Locate existing class names and usages before introducing new names.
3. Prefer minimal, targeted edits that preserve existing architecture and conventions.

While editing:
1. Keep namespace, class, and file naming consistent with the rules below.
2. Do not delete tests; move and update them with source changes.
3. Add or update a nearby `spec.md` for major behavior or architecture changes.

After editing:
1. Run relevant tests with `./test [file_pattern] [method_pattern]`.
2. Summarize behavior changes and list follow-up risks or TODOs.

## Conversation Discipline

- Do not hallucinate user feedback. Verify that text actually came from the user and not from tool output or your own reasoning.

## Change Safety Rules

- Do not perform destructive repository operations unless explicitly requested.
- Do not silently change public interfaces, persistence formats, or remote method contracts without documenting the change.
- For cross-worker, websocket, or ICC changes, verify queue encoding, whitelist entries, and context injection assumptions.
- If the worktree is already dirty, do not revert unrelated user changes.

### Temporary Scripts

- Place all temporary scripts (Lua, bash, etc.) inside the repository — use `tmp/` or the repo root. Never create them outside the repo directory.
- When running ad-hoc Lua scripts via `bash`, always use `./luajit` (not `./test`):

```bash
./luajit tmp/my_script.lua
```

`./luajit` is a wrapper around `./luajit.lua` that enforces a 2 GB memory limit via `ulimit -v`. The `./test` runner already applies this limit internally.

`./luajit` accepts Lua source code from stdin when the script path is `-`, so `./luajit - <<'EOF'` is valid for short ad-hoc checks. For reusable or multi-step scripts, prefer writing a temporary script under `tmp/` and running it by path; for short one-liners, use `./luajit -e '...'`.

## Batch Text Substitution

When performing mass find-and-replace (e.g., renaming namespaces, moving modules), scope substitutions by **line context** to avoid corrupting unrelated text like URLs, variable names, or data paths.

**Scope by line pattern, not by text alone:**

```bash
# Only touch require() calls
sed '/require.*"/ s/old.prefix/new.prefix/g' file.lua

# Only touch comments (covers --- annotations, -- inline casts, and all comment variants)
sed '/--/ s/old.prefix/new.prefix/g' file.lua
```

**Rules:**
- Never apply a bare `s/old/new/g` across entire files when the pattern could match variable names, URLs, config keys, or string literals.
- After substitution, verify with `grep` that no unintended lines were changed.
- If the pattern is short (e.g., `osu.`, `sph.`), always scope by line context — these can easily match inside URLs (`osu.ppy.sh`), variable names (`sph.metadata`), or table keys (`a.midi.constantVolume`).
- When moving modules, update require paths and class annotations separately, each scoped to their respective line patterns.
- Run tests after mass substitution to catch silent corruption.

## Project Map

- `rizu/`: modern game client and core systems. Start with `rizu/spec.md`.
- `sea/`: website, server-side logic, shared web infrastructure. Start with `sea/spec.md`.
- `aqua/`: general-purpose shared Lua infrastructure. Start with `aqua/spec.md`.
- `chart/`: chart infrastructure — data model, format parsers, scoring, transformation. Start with `chart/spec.md`.
- `sphere/`: legacy client code that is gradually being rewritten into `rizu/`. Start with `sphere/spec.md`.

Existing feature specs worth checking early:
- `rizu/build/spec.md`
- `rizu/library/spec.md`
- `rizu/select/spec.md`
- `rizu/preview/spec.md`
- `rizu/dlc/spec.md`
- `rizu/gameplay/spec.md`
- `rizu/engine/spec.md`
- `chart/format/sph/spec.md`

## Server Configuration Files

All server configuration lives at the repository root. Edit the source files and recompile before restarting.

### `nginx_config.lua` — OpenResty configuration source

Single source of truth for the OpenResty server. See `aqua/web/nginx/nginx_config.lua` for the base example. Controls:
- **`listen`** — port the server binds to (default `8180`)
- **`shared_dicts`** — shared memory dictionaries (e.g. `players`, `mp_rooms`). Any new shared dict must be declared here AND in a repo class
- **`package_path`** / **`package_cpath`** — additional Lua module search paths
- **`require`** — modules pre-loaded at server init
- **`handler`** — entry point module for request handling (`sea.app.handler`)

Edits are compiled into `nginx.conf` via:
```bash
./luajit aqua/web/nginx/compile.lua
```
This reads `nginx_config.lua` and processes `aqua/web/nginx/nginx.conf.template` (etlua) to produce `nginx.conf`. **Never edit `nginx.conf` directly** — it will be overwritten on the next compile.

### `app_config.lua` — Application runtime configuration

Runtime settings loaded by `sea.app.AppConfig` at startup. Controls:
- **`sessions_secret`** — session cookie signing key
- **`is_register_enabled`** / **`is_login_enabled`** — auth feature toggles
- **`recaptcha`** — reCAPTCHA site and secret keys
- **`osu_api`** — osu! OAuth client credentials and redirect URI
- **`multiplayer`** — multiplayer server address and port
- **`responsible_person`** — legal contact information

`sea/app/AppConfig.lua` ships the default shape with placeholder values. `app_config.lua` overrides it at runtime.

### `conf.lua` — LÖVE Framework configuration

Standard LÖVE `love.conf()` entry point. Configures:
- Window, graphics, and module settings for the game client
- Enabled/disabled LÖVE modules (physics is off, audio/graphics/threading on)
- Identity and save directory behavior

### `pkg_config.lua` — Module path configuration

Sets up `package.path` and `package.cpath` for both the game client and server. Adds:
- Root folder, `3rd-deps/lua`, `aqua`, and tree-sitter paths
- Platform-specific binary directories (`bin/linux64`, `bin/win64`, `bin/mac64`)
- Exports paths to Lua and LÖVE require systems

### `my.cnf` — MySQL client configuration

MySQL connection settings for `db_dump` / `db_restore` scripts. Keep credentials in `my.cnf` (gitignored); `my.cnf.example` tracks the template.

## Runtime Game Access

The game exposes a development MCP server when enabled in ignored `userdata/mcp.lua`. Agents may use it to inspect and verify runtime behavior that repository tools cannot observe.

- If a task needs a running game and MCP is unavailable, ask the user to start the game. Do not launch the graphical client implicitly.
- Prefer focused, schema-validated MCP tools over `lua_eval` for repeatable workflows. Agents may add a focused tool with nearby tests and spec updates when the runtime capability they need does not exist yet.
- After changing game-side MCP wiring or tools, ask the user to restart the game so the running process loads the changes. `restart_game` can perform later restarts once that tool is loaded.
- Treat `lua_eval` and destructive MCP tools as trusted developer capabilities and use them only when needed for the task.

See `rizu/net/spec.md` and `aqua/mcp/spec.md` for transport, session, security, and tool-result contracts.

## Building And Running

Run the game with the bundled LÖVE launchers:
- `game-appimage`
- `game-macos`
- `game-win64.bat`

Run tests with:

```bash
./test [file_pattern] [method_pattern]
```

Examples:

```bash
./test rizu/gameplay/GameplayTimings_test.lua
./test rizu/build
```

## Tech Stack

- **LuaJIT 2.1** everywhere — all runtime code targets LuaJIT 2.1. Use `./luajit` when running scripts from the command line.
- **OpenResty** for the server and website (`sea/`). All server-side code runs inside the OpenResty Lua environment.
- **LÖVE Framework** for the game client (`rizu/`, `sphere/`). The game is built as a LÖVE game and launched with the bundled launchers.

## Code Conventions

### Lua Style

- Follow `.editorconfig`: use tabs for indentation and do not indent empty lines.
- Omit empty `:new()` constructors.
- **Require Paths**: Use absolute paths starting from the nearest root defined in `pkg_config.lua` (e.g., `aqua/`, `3rd-deps/lua/`, or the project root). For example, use `require("json")` instead of `require("3rd-deps.lua.json")`, and `require("byte")` instead of `require("aqua.byte")`. Exceptions are `require("aqua.pkg")` and anything in the `preload/` folder (e.g., `require("preload.iconv")`).
- **Move all requires to the top of the file** — do not use inline/local requires except when breaking circular dependencies.
- **Prefer `function M.f()` format** over `M.f = function()` for module methods. This is more idiomatic Lua and works better with EmmyLua annotations.
- **Avoid Lua global name shadowing**: do not use `type`, `table`, `string`, or `pairs` as local variable names. Prefix with `_` or use an alternative name (e.g., `string_byte` for `string.byte`).
- **Fail fast on bad input**: avoid `value = config.value or fallback` patterns. Trust developer data and let invalid input error rather than silently substituting a default. Validate explicitly when needed.
- Prefer minimal comments and use EmmyLua for API documentation.

### Naming And Namespaces

- Do not derive class names only from file paths. Read the file definition or existing usages first.
- Legacy modules use `prefix.ClassName` naming such as `sea.UserConnectionsRepo`.
- Modern `rizu.*` modules use concise lowercase namespaces with PascalCase class names.
- Use semantic suffixes:
  - `Repo` for database or storage access
  - `Generator` for data transformation
  - `Task` for long-running orchestration
  - `Manager` for high-level coordination
- Filenames must match the class name.
- Interfaces are prefixed with `I`.

### Type Annotations

- Preserve and improve EmmyLua annotations when touching code.
- Prefer precise table annotations such as `{[KeyType]: ValueType}` over `table<KeyType, ValueType>`.
- Keep class annotations aligned with the actual runtime class name and namespace.
- For web resources, use the concrete class annotation pattern described in `sea/spec.md`.

### Annotation Rules

The repository uses LuaLS diagnostics with `no-unknown` enabled globally. Write annotations so the language server can prove types instead of silencing it after the fact.

General policy:
- Prefer inference when the type is already obvious from local code and LuaLS can resolve it.
- Add annotations when they improve public API clarity, remove ambiguity, or prevent `no-unknown` diagnostics.
- Do not add redundant annotations to every local just because a value has a type.
- Treat `---@diagnostic disable ... no-unknown` as a last resort, not a normal tool.

Annotate these by default:
- Named classes and interfaces with `---@class`.
- Public or shared object fields with `---@field` when LuaLS cannot already infer them from class initialization or typed assignment.
- Public functions and methods whose parameter or return types are not fully obvious from usage.
- Functions returning multiple values, optional values, or domain-specific aliases.
- Aliases for important unions, callback signatures, and structured data shapes with `---@alias`.
- Generic helpers with `---@generic` when the function preserves input-output type relationships.
- Important locals whose shape is otherwise unknown to LuaLS, especially empty tables that later gain typed fields or entries.

Usually do not annotate:
- Private locals initialized from obvious constructors or literals when LuaLS already infers them correctly.
- Simple one-line wrappers whose parameters and returns are fully inherited from a clearly typed callee, unless the wrapper is part of a public API surface.
- Values only used once in a tiny local scope when the inferred type is already precise.

Class rules:
- Every class-like module should declare its runtime class name with `---@class`.
- Add `---@operator call: TypeName` when the class is callable as a constructor.
- Do not add `---@field` for a field when LuaLS already infers it from a default primitive assignment on the class or from typed assignment in methods.
- Put structural fields on the class with `---@field` when instances are expected to carry them beyond a tiny local scope and LuaLS would not otherwise know they exist.
- Class annotations must match the real namespace and class name used by the module, not a guessed name derived only from the file path.
- Interface-like classes should use the `I` prefix and declare fields or methods that callers rely on.

**Canonical class example:**

```lua
local class = require("class")

-- Manages user connections and session state.
---@class app.Users
---@operator call: app.Users
---@field users {[string]: app.User}
local Users = class()

-- Class-level default — instances inherit this value.
Users.default_timeout = 30

---@param config app.Config
function Users:new(config)
	self.max_users = config.max_users
	self.users = {}
	-- Accumulator table — annotate at init so LuaLS knows the entry type.
	---@type app.Event[]
	self.events = {}
end

---@param user app.User
---@return boolean added
function Users:add(user)
	if #self.users >= self.max_users then
		return false
	end
	self.users[user.id] = user
	return true
end

---@param id string
---@return app.User? user
function Users:get(id)
	return self.users[id]
end

-- Returns nothing — no @return annotation needed.
function Users:clear()
	self.users = {}
end

return Users
```

Field rules:
- Use `---@field name Type` for stable instance fields, config fields, DTOs, and state containers.
- Use `---@field FieldName FieldType?` for legitimately optional fields.
- Prefer specific container types such as `string[]`, `integer[]`, or `{[string]: sea.User}`.
- When a field has a constrained set of string values, prefer an alias or explicit string union instead of plain `string`.
- If a field is first created in a method and LuaLS would not know its shape, prefer a local typed assignment at the write site, for example:

```lua
function FakeLogicNote:new()
	---@type any[]
	self.inputs = {}
end
```

Function rules:
- Define `---@param` and `---@return` annotations for functions and methods by default.
- The main exceptions are:
  - callbacks passed to a function that already defines the callback type,
  - implementations of inherited or interface methods whose parameter and return types are already inferred from the parent contract.
- Annotate returns with `---@return` for public functions, multi-return functions, and any function returning optional values or typed tables.
- Use one `---@return` per returned position, matching the actual order of values.
- Do not add `---@return nil` for functions that return nothing.
- Use `Type?` for optional values instead of vague `any` when absence is the real contract.
- Prefer domain aliases and named classes over `table`, `function`, or `any` whenever the real type is known.
- If a function returns nothing, use bare `return` or fall through naturally. Do not write `return nil` unless `nil` is an intentional value in a declared return position.

Local type rules:
- Use `---@type` for empty table initialization when later writes would otherwise produce unknown fields or unknown index types.
- Use `---@type` to pin a union or container type when inference would widen too far.
- Avoid `---@type any` unless the value is intentionally dynamic and no safer contract exists.
- When creating typed dictionary or array accumulators, annotate them at initialization time rather than adding suppressions on later writes.

Alias and generic rules:
- Use `---@alias` for reusable unions, string enums, callback signatures, and complex structural concepts that appear in multiple places.
- Keep aliases close to their owning module or type-definition file.
- Use `---@generic` only when there is a real type relationship to preserve, such as input element type flowing to the return value.
- When a generic helper depends on extra structural fields, pair the generic with a cast to a more specific helper shape only at the narrow point where that structure is required.

Casting rules:
- Prefer `---@cast` to refine a value after runtime checks that LuaLS does not already understand.
- Do not add a cast after `type(v) == "string"` when LuaLS already narrows it correctly.
- Cast to the narrowest true type.
- Do not use `---@cast` to lie about a value just to satisfy diagnostics.
- If repeated casts are needed, prefer reshaping the code or adding an earlier annotation so the type becomes naturally inferable.

FFI binding rules:
- FFI-heavy modules often produce many `unknown` types around `ffi.C`, `ffi.load(...)`, `ffi.new(...)`, `ffi.cast(...)`, pointer arithmetic, and cdata field access. Expect to add more explicit typing there than in ordinary Lua modules.
- Use typed wrapper classes for important cdata shapes, following the pattern in `aqua/7z.lua`.
- Add `---@class` declarations for meaningful pointer or struct views that LuaLS cannot infer well, for example typed pointers, stream structs, allocator structs, or exposed property structs.
- Put callable function-pointer members and known struct fields on those wrapper classes with `---@field`.
- When `ffi.new()` returns an array or out-parameter buffer, annotate the Lua view you actually rely on, such as `{[0]: c7z.ISzAlloc}` for single-element pointer arrays.
- Prefer annotating the result immediately after allocation or cast rather than scattering `no-unknown` suppressions across later field reads and writes.
- For raw byte buffers or pointer-indexed memory, introduce a narrow alias or wrapper class when indexed access is part of the contract.
- Keep FFI declarations and their annotations aligned with the real native headers and ABI layout. If the header changes, update both the `ffi.cdef` block and the corresponding EmmyLua shape.
- Add comments when struct layout must stay in sync with a vendored SDK or external binary, especially when a mismatch could cause silent memory corruption.
- Use narrow suppressions only where LuaLS still cannot model valid dynamic FFI behavior after reasonable wrapper typing.

Diagnostic suppression rules:
- Avoid file-wide or broad diagnostic disables for annotation issues.
- A local `---@diagnostic disable-next-line: no-unknown` or `disable-line` is acceptable only when:
  - the code is intentionally dynamic,
  - the runtime contract is correct,
  - a more precise annotation or refactor would be disproportionate or impossible.
- When suppressing `no-unknown`, keep the suppression as narrow as possible and prefer adding a short comment if the reason is not obvious from the line.

Preferred shapes:
- Prefer `{[KeyType]: ValueType}` over `table<KeyType, ValueType>`.
- Prefer `Type[]` for arrays.
- Prefer explicit string unions like `"linux"|"windows"` for closed sets of string values.
- Prefer concrete callback signatures in aliases, for example `---@alias util.ValidationFunc fun(v: any?): boolean?, string|valid.Errors?`.

Avoid these weak annotations unless they are truly the contract:
- `table`
- `function`
- `object`
- `any`

Use them only when the value is intentionally open-ended or the code is interfacing with genuinely untyped external data.

Patterns to prefer:
- Annotate test functions with `---@param t testing.T`.
- Annotate resource classes, repos, DTO-like records, and config tables explicitly.
- For validator-heavy code, refine after runtime checks with `---@cast` instead of defaulting entire flows to `any`.
- For dynamic parse loops such as `gmatch`, prefer a narrow suppression only if LuaLS cannot model the iterator variables after a reasonable annotation pass.
- For FFI bindings, use `aqua/7z.lua` as a model for pairing `ffi.cdef` declarations with EmmyLua wrapper classes for cdata pointers, function-pointer fields, and out-parameter arrays.

## Testing Rules

- Test files are first-class and must not be deleted.
- Test files should use the `_test.lua` suffix and stay next to the source they cover.
- Always run relevant tests after making changes.
- Prefer tests that validate behavior, invariants, failure modes, and internal contracts over tests that restate implementation details.
- If a module moves or is renamed, move and update its tests too.

Test file structure:
- Use `local test = {}` pattern instead of `return { ... }`.
- Define test functions with `function test.name(t)` format (not `test.test_name`), not as table entries.
- Add `---@param t testing.T` annotations to each test function.
- Return `test` at the end of the file.
- Use the assertion helpers on `t` such as `eq`, `ne`, `aeq`, `tdeq`, `has_error`, and `has_not_error`.

Example test file:

```lua
local MyModule = require("my.module")

local test = {}

function test.basic(t)
	t:eq(MyModule.doThing(), "expected")
end

return test
```

For ICC or shared-memory communication tests:
- Use `FakeSharedDict`.
- Prefer no-return remotes for one-way inter-connection messaging.
- Assert queue payloads directly with `t:tdeq(...)`.

## Documentation Rules

- Keep documentation close to the code.
- New features or major behavior changes must be documented in a nearby `spec.md`.
- Each `spec.md` should begin with:
  - `## Goal`
  - `## User Experience`
- Significant architectural choices should be recorded in an `## Architecture Decisions` or `## ADR` section.
- Stable runtime assumptions should be recorded in an `## Invariants` section when they affect correctness, performance, or cross-module behavior. Prefer documenting invariants in the nearest `spec.md` instead of scattering long explanatory comments through implementation files. Good candidates include ownership/lifetime rules, queue ordering, thread or worker boundaries, timing assumptions, protocol constraints, and cache consistency requirements.
- A `## Future Work and Open Questions` section is not a strict TODO list. It may contain exploratory ideas that require research and may later prove unnecessary, unsuitable, or lower-priority after implementation details are better understood.
- Use precise terminology. For example, do not use "difficulty" when you mean chart variation or chart file.

## When To Create Or Update A Spec

Update a nearby `spec.md` when you:
- add a new subsystem or major workflow,
- change behavior that affects users or other modules,
- introduce new architectural constraints,
- add or change important invariants that future edits must preserve,
- formalize conventions that future agents need in that folder.

Keep root `AGENTS.md` focused on universal rules. Put feature-specific details in the closest relevant `spec.md`.

## PI Agent

This repository ships custom PI extensions in `.pi/extensions/`. Agents running under PI have access to these in addition to the default tool set.

### Extensions

#### `run_tests`

Tool: `run_tests` — runs the Lua test suite via `./test --json` and returns structured results.

Parameters:
- `file_pattern` — file path pattern to match test files (e.g. `rizu/gameplay`, `GameplayTimings_test.lua`). Omit to run all tests.
- `method_pattern` — Lua pattern to match test method names within matched files (e.g. `auto_timings`).

Use `run_tests` instead of calling `./test` through `bash`. It parses JSON output, formats timing per file, and surfaces error details with file, line, and method context.

#### Auto-Test Notification

When the `edit` or `write` tool modifies a `.lua` file that has a corresponding `_test.lua` file, the extension posts a notification so the agent knows tests exist for that module.

### Common Pitfalls

- When using the `edit` tool, always pass `edits` as an array of objects (`[{oldText, newText}, ...]`). Passing a string (e.g. from JSON serialization) causes a validation error. Double-check the structure before calling.

### Extension Development Workflow

When modifying files in `.pi/extensions/`, changes do not take effect immediately. The user must run the `/reload` command to reload extensions. After editing an extension:

1. Tell the user to run `/reload` and wait for confirmation that they did so.
2. Do not test the changed extension (e.g., via `run_tests`) until the user confirms the reload.
3. Remind the user about `/reload` if they ask you to test changes without reloading first.
