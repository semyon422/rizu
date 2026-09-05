# SPH Chart Format (`chartbase/sph`)

## Goal
The SPH parser should load the text-based `.sph` chart format into data structures that the engine can consume without inventing unsupported timing concepts.

## User Experience
- SPH charts should parse predictably and produce the intended note timing.
- Missing tempo declarations should not be guessed through format extensions that the format does not define.
- Tests should be able to rely on a small set of stable timing assumptions without treating this document as the complete SPH format reference.

## Scope Note

This spec is intentionally incomplete. It records the parts of SPH that are most important for engine assumptions and common tests, but the actual format supports more features than the rules summarized below. When changing parsing or encoding behavior beyond these core assumptions, inspect the parser and tests in `chartbase/sph/` instead of relying only on this document.

## Testing-Relevant Rules

- Notes in the `# notes` section commonly use the form `"XXXX =Y"`.
- In that simplified testing form, `XXXX` represents note or column state and `Y` is the absolute time in seconds for the line.
- The format also includes other sections and features, including metadata and sounds, which are important to the full parser but are often unnecessary in focused timing tests.

## Timing Rules

- The engine requires at least two note lines to determine timing and average beat duration.
- SPH does not support explicit tempo declarations.
- Tempo is inferred from the time difference between note lines, so parser or engine changes must preserve that assumption.
- The encoder must preserve interval vertices and measure markers even when no visual point exists at that timing point. Dropping a standalone vertex can make the decoder extrapolate the rest of the chart from a short auxiliary interval and visibly compress the preview.

## Verification

- When changing SPH parsing or timing behavior, run focused tests in `chartbase/sph` and any gameplay tests that depend on SPH timing.
