## Goal

The `rizu/notifications/` module keeps the notifications for the player and the background tasks that are running, so any user interface can show them through `rizu.api.Notifications`.

## User Experience

- Things that happen out of sight are posted once: a saved screenshot, a login, a submitted score, charts that failed to load, a UI listener that failed.
- Long work shows as a task with progress, or as busy when its size is unknown. Each library scan stage is one task.
- The same notification posted again moves to the top and counts up instead of filling the list.

## Architecture Decisions

- `Notifications` is the store. It has no LÖVE dependency, runs on the main thread, and sends changes through the `onChanged` observable. `GameController` owns it as `game.notifications`.
- A notification carries a `type` and `params` for translation and English `title`/`text` as the fallback, because the game has no localization and each UI translates on its own.
- Actions keep their functions in the store. UIs see `id` and `label` and run one with `runAction(id, index)`.
- `GameNotifications` connects existing observers (library status, online client, screenshots, API listener errors) to the store, so the subsystems do not know about notifications.
- Only this session is kept, at most `MAX_NOTIFICATIONS`.

## Invariants

- Posting from a failing listener of the notifications API area does not recurse.
- The unread count never exceeds the number of notifications.

## Future Work and Open Questions

- Server messages: the server has no way to send them to the client yet; the `server` kind is reserved for them.
- A logout notification needs an explicit logout event: `user_changed` with no user also means a lost connection.
