--- Tests for bancho model Channel.

local Channel = require("bancho.model.Channel")
local Privileges = require("bancho.constants.Privileges")

local test = {}

function test.channel_creation(t)
	local c = Channel:new("#test", "Test topic")
	t:eq(c.name, "#test")
	t:eq(c.real_name, "#test")
	t:eq(c.topic, "Test topic")
	t:eq(c.auto_join, true)
	t:eq(c.instance, false)
	t:eq(c:canRead(Privileges.UNRESTRICTED), true)
	t:eq(c:canWrite(Privileges.UNRESTRICTED), true)
end

function test.channel_add_remove(t)
	local c = Channel:new("#test", "Test")
	local player = {id = 1}

	c:add(player)
	t:eq(c:contains(player), true)
	t:eq(c:contains("#test"), false) -- string match checks player name, not channel name

	c:remove(player)
	t:eq(c:contains(player), false)
end

function test.channel_read_priv(t)
	local c = Channel:new("#test", "Test", bit.bor(Privileges.UNRESTRICTED))
	t:eq(c:canRead(Privileges.UNRESTRICTED), true)
	t:eq(c:canRead(0), false)
end

function test.channel_write_priv(t)
	local c = Channel:new("#test", "Test", 0, bit.bor(Privileges.MODERATOR))
	t:eq(c:canWrite(Privileges.MODERATOR), true)
	t:eq(c:canWrite(0), false)
end

function test.channel_string_match(t)
	local c = Channel:new("#test", "Test")
	-- String match: checks if player.id is a key
	local player = {id = "test"}
	c:add(player)
	t:eq(c:contains("#test"), false) -- "test" is not a key
end

return test
