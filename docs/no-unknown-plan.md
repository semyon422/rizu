## Goal

Reduce first-party LuaLS `no-unknown` diagnostics from the current stable baseline of about 5,200 without weakening type contracts or disguising analyzer defects as valid typing.

A zero-warning target is aspirational, not an unconditional acceptance criterion. Some diagnostics can be LuaLS inference defects, especially around mutable locals, loop accumulators, callback flows, dynamic tables, FFI, and metatable-heavy code.

## User Experience

Developers should see `no-unknown` only where Lua values are intentionally dynamic or LuaLS cannot represent a valid runtime contract. Normal application code should expose useful types through inference or concise EmmyLua annotations.

Changes should improve hover, navigation, completion, and contract checking. They should not add broad `any` annotations merely to make the warning counter decrease.

## Baseline

Take every baseline only after:

```json
{
  "operation": "diagnostic_stability",
  "wait": true,
  "stableSeconds": 5,
  "timeoutSeconds": 25
}
```

If the operation times out, repeat it before recording counts. Then use `diagnostic_summary` with `code: "no-unknown"`.

Stable baseline captured during planning: approximately 5,200 warnings.

| Directory | Count | Share |
|---|---:|---:|
| `aqua/` | 1,651 | 31.8% |
| `chart/` | 978 | 18.8% |
| `rizu/` | 918 | 17.7% |
| `sphere/` | 877 | 16.9% |
| `bancho/` | 342 | 6.6% |
| Other | 434 | 8.3% |

Counts can change as source and LuaLS evolve. The stable snapshot, not this table, is authoritative.

## Warning Classification

Classify a warning before changing code. Use the first matching category.

### A. Missing public contract

Examples:

- unannotated function parameters or returns,
- class fields created dynamically,
- DTO/config/schema tables with no declared shape,
- callback signatures that lose parameter types.

Preferred fix: add or improve a named class, alias, field, parameter, return, or callback type at the contract boundary.

### B. Untyped local container

Examples:

- `{}` later used as an array or dictionary,
- accumulators filled in loops,
- lookup maps built from typed objects.

Preferred fix: annotate initialization with the narrow container type, such as `---@type rizu.Tool[]` or `---@type {[string]: rizu.Tool}`.

### C. Narrowing or generic relationship not represented

Examples:

- validated decoded JSON remains unknown,
- a helper preserves an input/output element type,
- a checked union is not narrowed by LuaLS.

Preferred fix: reshape validation, add a generic relationship, or use a narrow `---@cast` immediately after the runtime check.

### D. FFI/native boundary

Examples:

- `ffi.C` and `ffi.load` functions,
- cdata pointers, arrays, and struct fields,
- callback and allocator state.

Preferred fix: add typed wrapper classes and aliases near the `ffi.cdef`, following `aqua/7z.lua`. Type allocation/cast results once instead of suppressing every later access.

### E. Dynamic framework or metatable code

Examples:

- immediate-mode UI state,
- class construction internals,
- serializers and schema builders,
- intentionally open plugin/config data.

Preferred fix: model stable structure and leave only the truly dynamic edge open. `any` is acceptable only when openness is the actual API contract.

### F. Analyzer defect or unsupported inference

Examples:

- a typed numeric local is still flagged on `i = i + 1`,
- equivalent rewrites move rather than eliminate the warning,
- hover proves a concrete type while `no-unknown` still fires,
- a minimal valid example reproduces against the installed LuaLS.

Preferred fix: do not distort production code. Record a minimal reproducer and LuaLS version, then use one narrow `---@diagnostic disable-next-line: no-unknown` at the affected expression with a short issue/reproducer comment.

## Fix Policy

Apply remedies in this order:

1. Improve an existing owning type or public function contract.
2. Add a narrow local container annotation.
3. Refactor validation/control flow so LuaLS can narrow naturally.
4. Add a precise alias, generic, wrapper class, or cast.
5. Use a narrow suppression only for intentional dynamics or confirmed analyzer limitations.

Do not:

- disable `no-unknown` globally or for an entire first-party directory,
- add file-wide suppression,
- annotate a value as `any` when a domain type is known,
- add redundant annotations to every obvious primitive,
- change runtime behavior solely to appease LuaLS,
- mix formatting or unrelated refactors into warning-cleanup commits.

## False-Positive Triage Protocol

Before calling a warning a LuaLS bug:

1. Inspect hover at the exact warning range and at the value's definition.
2. Check whether a missing upstream contract explains the loss of type.
3. Try a precise local annotation or cast in a temporary edit.
4. Restart LuaLS and wait for diagnostic stability.
5. If still suspicious, create a minimal script under repository `tmp/` that preserves the pattern.
6. Run the installed LuaLS version against the reproducer or verify it in an isolated VS Code file.
7. Record:
   - LuaLS version,
   - minimal code,
   - expected type,
   - actual warning range,
   - whether a harmless equivalent rewrite changes the result.
8. Add only a line-level suppression in production, linked to the local reproducer or upstream issue.

Delete temporary reproducers after filing/documenting them unless they become regression fixtures.

## Rollout

### Phase 1: Pilot modern typed modules

Start with `rizu/ai/`, excluding FFI-heavy probes initially. It has nearby specs/tests and modern contracts. Use the pilot to establish annotation and suppression review conventions.

Candidate order:

1. `rizu/ai/NeedleToolRegistry.lua`
2. `rizu/ai/NeedleWorker.lua`
3. `rizu/ai/NeedleModel_test.lua`
4. remaining non-FFI `rizu/ai` modules
5. `NeedleGpuProbe.lua` and `NeedleGpuEncoderProbe.lua` as a separate FFI batch

Exit criteria:

- zero actionable `no-unknown` in the pilot scope,
- every remaining warning has a narrow documented suppression,
- relevant tests pass,
- no new non-`no-unknown` diagnostics.

### Phase 2: Shared infrastructure by pattern

Work in coherent batches rather than directory-wide sweeps:

1. JSON/schema/validation flows (`aqua/ai/openai`, MCP, web DTOs)
2. typed containers and callbacks (`aqua`, `rizu`)
3. FFI modules (`aqua/ai/needle`, graphics/audio/native wrappers)
4. tests and fixtures after production contracts stabilize

Fix shared contracts before call sites; one owner annotation may remove many downstream warnings.

### Phase 3: Chart transformation/scoring

Prioritize high-count files whose warnings come from untyped note/line/lane structures. Define domain aliases/classes near the owning chart model before editing algorithms.

Do not begin with `NotePreprocessor.lua` by sprinkling casts: its warnings indicate missing structural types for notes, generated body/tail notes, lines, and lanes.

### Phase 4: Server and Bancho

Separate protocol/DTO typing from algorithm-heavy or vendored-style modules. Treat crypto tables and byte arrays as explicit aliases rather than generic tables.

### Phase 5: Legacy Sphere and user data

Handle `sphere/` after modern/shared contracts are stronger. Prefer migrating or reusing existing modern types where truthful. Consider excluding generated or user-owned data only when it is not maintained first-party source.

## Batch Size and Commits

- Target 1–5 related files per batch.
- Capture stable before/after counts for the scope and workspace.
- Keep FFI, test-fixture, and legacy batches separate.
- Commit by contract or subsystem, not by arbitrary warning count.
- Review surprising large count drops: they often indicate an upstream annotation improvement, but can also indicate LuaLS had not stabilized.

## Validation Checklist

For every batch:

1. Record stable scoped and workspace `no-unknown` baselines.
2. Inspect nearby specs and existing types.
3. Make minimal typing changes.
4. Run LuaLS diagnostics for each edited file.
5. Wait for diagnostic stability.
6. Confirm scoped `no-unknown` decreased as expected.
7. Confirm no new errors or other warning categories appeared.
8. Run relevant tests.
9. Run `git diff --check` in the correct repository/submodule.
10. Document confirmed LuaLS defects and narrow suppressions.

## Architecture Decisions

### Quality over zero

The metric is actionable unknowns removed, not warnings hidden. A precise documented suppression is preferable to a dishonest type.

### Type owners first

Annotations belong at the nearest stable owner: classes, DTOs, config shapes, callbacks, FFI wrappers, and domain aliases. Call-site casts are a fallback.

### Stable snapshots only

Diagnostic counts are accepted only after the adapter reports the configured quiet interval. Counts observed during workspace analysis are not progress metrics or baselines.

## Future Work and Open Questions

- Add adapter support for exporting all matching diagnostic ranges to a repository-local JSON report for offline clustering.
- Build a small regression suite of confirmed LuaLS inference defects relevant to this codebase.
- Decide whether generated/userdata Lua files should remain part of first-party diagnostic targets.
- Reassess false positives after LuaLS upgrades before retaining suppressions.
