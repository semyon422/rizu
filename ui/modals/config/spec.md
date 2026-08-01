## Goal

Provide a section-based settings modal for the modern `ui.UiConfig` store.

## User Experience

Settings are grouped under named, illustrated sections and use the shared form controls. Changes to checkboxes, sliders, and choices apply immediately. Textbox edits commit when keyboard focus leaves the textbox.

## Architecture Decisions

`Section` is a stateful definition rather than a view. It owns a name, icon, arbitrary presentation state, and a builder that returns the controls currently applicable to that state. Calling `Section:invalidate()` schedules the modal to rebuild its rows on the next update.

Each concrete section lives in its own module under `ui/modals/config/sections/`. All generated `FormControl` instances are direct rows of the modal's single `Form`. Section headings are non-selectable rows in the same form. `ControlFactory` binds modern flat config keys to controls; legacy nested settings are intentionally out of scope.

## Invariants

- A section never owns or draws views.
- Structural changes are deferred until `Config:update()` and never mutate rows from an input callback.
- Rebuilding closes dropdown overlays and clears form selection before replacing rows.
- Every setting control may carry a localized name, search keywords, a stable config key, and an optional `tip` for a future tip view.
- Textboxes notify their change callback only on focus loss and only when their value changed since the previous commit.
