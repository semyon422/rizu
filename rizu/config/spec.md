## Goal

Provide one small, typed, observable configuration store for Rizu settings.

## Design

Configuration keys are plain strings. `rizu.config.Settings` contains optional constants for shared keys and constructs the application settings store. `Config` owns defaults, explicit values, subscriptions, and JSON persistence.

Defaults are registered directly on a config:

```lua
config:setDefaultNumber("audio.volume.master", 0.5, 0, 1, 0.01)
config:setDefaultChoice("graphics.interface", "new", {"old", "new"})
config:setDefaultBoolean("misc.show_fps", false)
config:setDefaultString("profile.name", "")
config:setDefaultKeyBindings("ui.cancel", {{key = "escape"}})
```

Number definitions include minimum, maximum, and step metadata. Number setters reject values outside the configured range. Key bindings are arrays of `{key, control?, shift?, alt?, super?, allow_repeat?}` records. Typed getters and setters fail for unknown keys, incorrect types, invalid bindings, and invalid choices. Duplicate defaults also fail. There are no setting objects, nested schema discovery, transient state, commits, or a config registry.

## Changes

Callers can subscribe to one key or every key:

```lua
local unsubscribe = config:subscribeBoolean("misc.show_fps", function(value, old_value, key)
	view:setVisible(value)
end)

unsubscribe()
```

Callbacks run only when the effective value changes.

## Persistence

`Config` receives a filesystem and path at construction. `load()` and `save()` use flat JSON. Only values differing from defaults are stored. Unknown persisted keys are ignored for compatibility; invalid values make loading fail without changing the current config.
