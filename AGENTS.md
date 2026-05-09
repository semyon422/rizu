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

## Change Safety Rules

- Do not perform destructive repository operations unless explicitly requested.
- Do not silently change public interfaces, persistence formats, or remote method contracts without documenting the change.
- For cross-worker, websocket, or ICC changes, verify queue encoding, whitelist entries, and context injection assumptions.
- If the worktree is already dirty, do not revert unrelated user changes.

## Project Map

- `rizu/`: modern game client and core systems. Start with `rizu/spec.md`.
- `sea/`: website, server-side logic, shared web infrastructure. Start with `sea/spec.md`.
- `aqua/`: general-purpose shared Lua infrastructure. Start with `aqua/spec.md`.
- `chartbase/`: chart parsers and format-specific loaders. See format-local specs when present.
- `sphere/`: legacy client code that is gradually being rewritten into `rizu/`. Start with `sphere/spec.md`.

Existing feature specs worth checking early:
- `rizu/build/spec.md`
- `rizu/library/spec.md`
- `rizu/select/spec.md`
- `rizu/preview/spec.md`
- `rizu/dlc/spec.md`
- `rizu/gameplay/spec.md`
- `rizu/engine/spec.md`
- `chartbase/sph/spec.md`

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

## Code Conventions

### Lua Style

- Follow `.editorconfig`: use tabs for indentation and do not indent empty lines.
- Omit empty `:new()` constructors.
- Avoid using Lua global names like `type`, `table`, `string`, or `pairs` as locals. If needed, prefix with `_`.
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
- Use `Type?` for optional values instead of vague `any` when absence is the real contract.
- Prefer domain aliases and named classes over `table`, `function`, or `any` whenever the real type is known.

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

Test structure:
- A test file returns a table of test functions.
- Each test function receives `t` of type `testing.T`.
- Use the assertion helpers on `t` such as `eq`, `ne`, `aeq`, `tdeq`, `has_error`, and `has_not_error`.

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
- Use precise terminology. For example, do not use "difficulty" when you mean chart variation or chart file.

## When To Create Or Update A Spec

Update a nearby `spec.md` when you:
- add a new subsystem or major workflow,
- change behavior that affects users or other modules,
- introduce new architectural constraints,
- formalize conventions that future agents need in that folder.

Keep root `AGENTS.md` focused on universal rules. Put feature-specific details in the closest relevant `spec.md`.
