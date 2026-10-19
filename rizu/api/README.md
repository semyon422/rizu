# rizu/api

What a user interface may use from the game. `GameApi` is created once with the game and a UI gets it as `ui.api`.
The default UI in `ui/` is the example; `./ui-preview` runs it on a fake game, so you can write a UI without the game.

```lua
local api = ui.api
api.charts:on("selection_changed", function(chart) title:setText(chart and chart.title or "") end)
api.play:start({}, function(ok, err) if ok then showGameplay() else showError(err) end end)
```

Check `api.version` (now `1`). It goes up when something is removed or changes meaning; adding is free.

## Areas

| Area | What it is for |
|---|---|
| `api.charts` | The chart library: sets, charts, selection, search, sort, filters, collections, online catalog. |
| `api.scores` | Scores of the selected chart; loading one for the result screen. |
| `api.media` | Background, audio preview, notes preview, background animation, beat, spectrum. |
| `api.online` | The account: name, avatar, online count, login and logout. |
| `api.play` | Music speed, mods, mutators, judging, and `start()`. |
| `api.gameplay` | The play in progress: drawing, pause and retry, score, notes for skins. Lua skins get this object too. |
| `api.result` | How the last play went. |
| `api.skins` | Gameplay skins and the chosen one. |
| `api.input` | Key bindings. |
| `api.library` | Chart folders, scanning them, and other rhythm games installed on this computer. |
| `api.app` | The user interface that runs, the audio device, screenshots. |
| `api.video_export` | Writes frames the UI draws into an animated WebP (no audio) with the system `ffmpeg`. |
| `api.settings` | Every setting. Keys are in `rizu/config/spec.md` and count as API: they are not renamed silently. |

Every file starts with a comment that shows how to use it, and every function is documented. Read those; this
file only has the rules.

## Rules

- **Reading** is a plain getter. Nothing is copied: a chart, a score or a mutator is the game's own table. Read the
  fields the class declares (`rizu.api.Chart`, `rizu.api.Score`, `rizu.api.Mutator`, ...) and nothing else. Do not
  change them and do not keep them past the frame unless the function says so.
- **Changing** is a method on the area. It is saved and applied at once.
- **Something that finishes later** is a command with `f(ok, err)` (`play:start`, `online:login`,
  `scores:loadSelectedResult`, `result:retry`, `charts:checkLibraryEmpty`). `err` is text you can show. Where the state
  lasts, it also has a getter and an event (`charts:isLoading()` and `"sets_loading"`).
- **Events** are `area:on(event, f)`. It returns a function that unsubscribes. The events of each area are in its
  `Event` alias. A listener that throws is reported and does not stop the others. When the game replaces the UI it
  removes all listeners, so a UI does not have to unsubscribe at the end.
- **Lists** are asked by index (`charts:getSet(i)`), never copied. A row can be not loaded yet, see `charts`.

## Not covered yet

A UI that wants these still has `ui.game`, which is the whole `GameController` and changes without notice. It is `nil`
in `./ui-preview`.

- DLC downloads, multiplayer lobbies, the AI chat, the command palette and the needle tools, mapperatorinator.
- The command registry (`ui.command_registry`, `rizu/commands/`). Commands take `game`.
- The editor.

The weak parts of the area that are covered are in `REVIEW.md` ("Status") and as `TODO: weak spot` in the code.

## Writing the fake

`rizu/api/fake/` has one `Fake<Area>` for every area. A fake holds data and remembers what was set; it has no logic.
`FakeGameApi_test` fails when a real function has no fake, so add both together.
