# Clearing subscribers

When the user changes the UI at runtime the game probably doesn't clear event subscribers which means the game will still have an access to the old UI and will call there methods which is stupid and we don't need that.

It's actually not that bad right now, but we can at least clear the subscribers in rizu/config
It's the responsibility of the UI to unsubscribe

