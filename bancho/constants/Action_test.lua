local Action = require("bancho.constants.Action")

local test = {}

function test.fromValue_known(t)
	-- All known action values should return the same value
	t:eq(Action.fromValue(0), 0)  -- IDLE
	t:eq(Action.fromValue(2), 2)  -- PLAYING
	t:eq(Action.fromValue(5), 5)  -- MULTIPLAYER
	t:eq(Action.fromValue(11), 11) -- LOBBY
	t:eq(Action.fromValue(13), 13) -- OSUDIRECT
end

function test.fromValue_unknown(t)
	-- Unknown values should fall back to the raw value
	t:eq(Action.fromValue(99), 99)
end

function test.enum_values(t)
	t:eq(Action.IDLE, 0)
	t:eq(Action.AFK, 1)
	t:eq(Action.PLAYING, 2)
	t:eq(Action.EDITING, 3)
	t:eq(Action.MODDING, 4)
	t:eq(Action.MULTIPLAYER, 5)
	t:eq(Action.WATCHING, 6)
	t:eq(Action.UNKNOWN, 7)
	t:eq(Action.TESTING, 8)
	t:eq(Action.SUBMITTING, 9)
	t:eq(Action.PAUSED, 10)
	t:eq(Action.LOBBY, 11)
	t:eq(Action.MULTIPLAYING, 12)
	t:eq(Action.OSUDIRECT, 13)
end

return test
