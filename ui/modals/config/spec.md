## Goal

Provide a section-based settings modal for the modern `ui.UiConfig` store.

## User Experience

Settings are grouped under named, illustrated sections and use the shared form controls. A padded section list on the left shows each section's icon and name, highlights hovered items, and displays the selected section on the right. Changes to checkboxes, sliders, and choices apply immediately. Textbox edits commit when keyboard focus leaves the textbox.

## Architecture Decisions

`Section` is a stateful definition rather than a view. It owns a name, icon, arbitrary presentation state, and a builder that returns the controls currently applicable to that state. Calling `Section:invalidate()` schedules the modal to rebuild its rows on the next update.

Each concrete section lives in its own module under `ui/modals/config/sections/`. All generated `FormControl` instances are direct rows of the modal's single `Form`. Section headings are non-selectable rows in the same form. `ControlFactory` binds modern flat config keys and nested legacy setting paths to controls. Legacy bindings mutate the loaded settings table without writing it immediately.

The audio section exposes master, music, keysound, and metronome volume. Stored volumes remain linear values in `[0, 1]`. The logarithmic presentation converts them to and from decibels and changing the presentation mode invalidates the section.

## Invariants

- A section never owns or draws views.
- Structural changes are deferred until `Config:update()` and never mutate rows from an input callback.
- Rebuilding closes dropdown overlays and clears form selection before replacing rows.
- Every setting control may carry a localized name, search keywords, a stable config key, and an optional `tip` for a future tip view.
- Textboxes notify their change callback only on focus loss and only when their value changed since the previous commit.
- Audio volume storage is always linear even when sliders display decibels.
