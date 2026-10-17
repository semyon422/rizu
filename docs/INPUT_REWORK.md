# Input rework

Found on 2026-10-14, branch `refactor2025`, while writing `api.input`. Items marked **(run)** I reproduced with
a small test; the rest I found by reading the code. Nothing here is fixed yet. `api.input` already exists
(`rizu/api/Input.lua`), so the UI side will not change when the fixes below land.

The path today: LÖVE callback → `LoopEvents:transformInputEvent` makes an `inputchanged(device, id, key, state)`
event → `GameplayInteractor:receive` → the gamemode's `Input:transform` → `VirtualInputEvent` → gameplay session.
Only mania uses `InputBinder` and the `input` config.

## Bugs in what exists

1. **One key can drive two columns, and nobody says so. (run)** Bind `a` to `key1` and `key2` and
   `InputBinder:transform` returns column 1. It walks the config with `pairs`, so which column wins is not
   defined (a table with holes or a different insertion order can pick the other one). The modal does not warn.
   Decide the rule — either `setKey` removes the key from the other column (what most games do), or two columns
   fire at once — and make `transform` deterministic.
2. **`InputBinder:getBindsCount` is wrong after clearing a slot. (run)** It uses `ipairs` over a table that can
   have holes. Bind both scratch slots, clear slot 1, and it returns 0 although slot 2 is bound. `clearBinding`
   (right click in the modal) creates exactly this hole. Nothing in the repository calls it today, so either fix
   it with `pairs` or delete it.
3. **A cleared slot leaves a hole in the saved config.** `binds[index] = nil` on a JSON array. How it
   serialises depends on the encoder (`null` filler, or the array turns into an object). Save the bindings as a
   map, or compact on write.
4. **The `transform` loop is a linear scan over every bind on every key event.** Fine for 7 columns, but it runs
   for each key press in the input thread. Build a `[device_type][device_id][key] → {column, slot}` lookup when
   the binder is created and rebuild it on `setKey`. This also fixes item 1 for free, because the lookup can
   only hold one column per key.
5. **`EventIdMapper` ids can leak.** The id string is `device_id_key_slot`; it is freed only on a release event
   (`event.state == false`). If a key goes down, the config changes (or the screen changes) and the release
   arrives for a key that is no longer bound, the id is never freed. Free on `unload` of the play, and when the
   binder is rebuilt.
6. **`getKey` falls over when a slot is nil but later slots exist.** Same hole as item 3; the UI draws an empty
   cell and the game works, but `unpack(bind)` on a hole's neighbour is one bad config away from an error. Load
   should validate the shape of `configs.input` (a table of columns of `{key, device_type, device_id}`) and drop
   what does not fit; today a hand-edited or old config goes straight into `transform`.

## Things that do not work

7. **Only keyboards can be bound.** The modal reads `e.device or "keyboard"` and `e.device_id or 1`, but the
   `gui` key events have no `device` field. A gamepad, joystick or MIDI key never reaches the modal, so the
   `gamepad`/`joystick`/`midi` branches in `InputBinder`, `InputDevice` and `LoopEvents` can be played with but
   not set up from the game. The binder needs its own "listen for the next physical event" mode (taking
   `inputchanged` from the loop, not the UI's key events), which would also let the modal show which device
   a key belongs to.
8. **The keyboard id is always 1.** `LoopEvents:transformInputEvent` hardcodes `"keyboard", 1`. Two keyboards
   (or a keyboard and a macro pad) cannot be told apart, which is a real feature for a rhythm game. LÖVE does not
   give the keyboard id, so this needs a decision, not a patch: keep one keyboard and say so.
9. **Gamepad and joystick ids are `getID()`.** That id is assigned on connect and can change after replugging or
   a restart, so bindings saved against it point at the wrong pad or at nothing. LÖVE has `getGUID()`, which
   stays the same for the same model (not for two identical pads).
10. **Only mania reads the config.** Taiko hardcodes `f j d k`, SDVX `a s l ; …`, aim `z x` and mouse buttons,
    catch has its own `Input`. `api.input` is therefore mania-only today, and a player who rebinds 4K keys finds
    the other modes unchanged without any sign of it. Either give every gamemode an `input` section in the config
    with these as the defaults, or state in the modal and in the API docs that it is mania only.
11. **Gamemode `Input` classes disagree on the event.** Mania takes `inputchanged` with a scancode; taiko and
    sdvx take `keypressed` and read `event[1]` / `event[2]` ("Prefer scancode when provided by LÖVE" — so one of
    them is a keycode on some layouts); aim takes both. A layout change (AZERTY, Dvorak) therefore moves
    taiko's keys but not mania's. One transformed event for all of them (`inputchanged` with the scancode) and
    one table of defaults per mode removes the problem.
12. **`sphere/models/InputModel.lua` is dead.** `GameController` creates it (`:140`) and nothing reads
    `self.inputModel`. It is 152 lines about the same config. Delete it, and its `configModel:open("input")`
    owner should be `InputBinder` or a small `InputConfig`.

## Missing

13. **No defaults and no reset to defaults.** `resetBindings` empties the mode, so a player who presses it has
    an unplayable 4K until they bind every key. The defaults live in `userdata/settings.lua`, outside the code.
    Put the default layout per input mode next to `InputMode` and make reset restore it.
14. **Bindings are per input mode name** (`4key`, `7key`), shared by every skin and chart. Fine, but a 7K+1S
    chart and a 7K chart do not share keys, so a player with a scratch key on a 7K layout rebinds from scratch
    for each. A `7key1scratch` layout that falls back to `7key` for the keys they share would remove most of it.
15. **The pause, offset and play-speed keys are not in the input config's API.** `input.pause`,
    `input.offset.*`, `input.playSpeed.*` in `userdata/settings.lua` are read directly. They should be part of
    `api.input` too (for example `getHotkey(name)` / `setHotkey(name, key)`) before a custom UI needs to
    change them.
16. **No test covers `transform` end to end.** `InputBinder_test` exists; there is no test that sends an
    `inputchanged` through `GameplayInteractor:receive` for each gamemode. Add one per gamemode once item 11 is
    done — that is the test that would have caught the keycode / scancode split.

## Suggested order

1. Items 1, 2 and 4 together: one lookup table in `InputBinder`, rebuilt on change, with the rule for duplicate
   keys. Small and removes two bugs.
2. Item 6 (validate on load) and 3 (the saved shape), because 13 and 14 change that shape anyway.
3. Item 11, then 10: one event and one defaults table for every gamemode.
4. Item 13 (defaults, reset), item 12 (delete `InputModel`).
5. Items 7–9 (devices) as one piece of work: they all need a decision about how a device is named.
