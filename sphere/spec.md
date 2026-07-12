# Legacy Client Notes (`sphere`)

## Goal
The `sphere/` tree contains the older client architecture that is still maintained where necessary but is being gradually replaced by `rizu/`. Work here should preserve behavior and avoid introducing new long-term architectural debt unless the task is explicitly legacy-focused.

## User Experience
- Legacy screens and flows should continue working while the project transitions functionality toward `rizu/`.
- Bug fixes in `sphere/` should prioritize stability and compatibility with existing save data, UI flows, and integration points.

## Working Rules

- Prefer implementing new major features in `rizu/` unless the user explicitly needs `sphere/`.
- When touching `sphere/`, look for existing patterns in nearby code rather than importing modern `rizu` structure wholesale.
- If a fix exposes a migration opportunity, document it instead of performing a broad rewrite unless requested.

## Architecture Notes

- Expect older naming, structure, and coupling patterns here.
- Keep edits scoped and avoid churn that makes future migration harder.
- If gameplay behavior overlaps with modern modules, use `rizu` specs as conceptual references but preserve the local architecture unless the task is specifically a migration.
- `sphere.ui.BackgroundModel` receives the shared `rizu.net.NetworkService` for HTTP backgrounds; network download stays on the main-thread cosocket scheduler, while image decoding remains in `thread.async`.
