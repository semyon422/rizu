--- Tests for bancho model ChannelCollection.

local ChannelCollection = require("bancho.model.ChannelCollection")
local Channel = require("bancho.model.Channel")

local test = {}

function test.collection_empty(t)
	local c = ChannelCollection()
	t:eq(c:len(), 0)
	t:eq(c:get("#test"), nil)
end

function test.collection_add_get(t)
	local c = ChannelCollection()
	local ch = Channel("#test", "Test channel")

	c:add(ch)
	t:eq(c:len(), 1)
	t:eq(c:get("#test"), ch)
end

function test.collection_remove(t)
	local c = ChannelCollection()
	local ch = Channel("#test", "Test channel")

	c:add(ch)
	c:remove(ch)
	t:eq(c:len(), 0)
	t:eq(c:get("#test"), nil)
end

return test
