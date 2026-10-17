--- Tests for bancho model PlayerCollection.

local PlayerCollection = require("bancho.model.PlayerCollection")
local Player = require("bancho.model.Player")

local test = {}

function test.collection_empty(t)
	local c = PlayerCollection()
	t:eq(c:len(), 0)
	t:eq(c:get(nil, nil, nil), nil)
end

function test.collection_add_get(t)
	local c = PlayerCollection()
	local p = Player(1, "TestUser", 1)

	c:add(p)
	t:eq(c:len(), 1)
	t:eq(c:get(nil, 1), p)
	t:eq(c:get(p.token), p)
	t:eq(c:get(nil, nil, "TestUser"), p)
end

function test.collection_remove(t)
	local c = PlayerCollection()
	local p = Player(1, "TestUser", 1)

	c:add(p)
	c:remove(p)
	t:eq(c:len(), 0)
	t:eq(c:get(nil, 1), nil)
end

function test.collection_duplicate_add(t)
	local c = PlayerCollection()
	local p = Player(1, "TestUser", 1)

	c:add(p)
	c:add(p) -- should be a no-op
	t:eq(c:len(), 1)
end

function test.collection_enqueue(t)
	local c = PlayerCollection()
	local p1 = Player(1, "User1", 1)
	local p2 = Player(2, "User2", 1)

	c:add(p1)
	c:add(p2)

	c:enqueue("hello")
	t:assert(p1:dequeue() == "hello")
	t:assert(p2:dequeue() == "hello")
end

function test.collection_enqueue_immunity(t)
	local c = PlayerCollection()
	local p1 = Player(1, "User1", 1)
	local p2 = Player(2, "User2", 1)

	c:add(p1)
	c:add(p2)

	c:enqueue("hello", { p1 })
	t:eq(p1:dequeue(), nil)
	t:assert(p2:dequeue() == "hello")
end

return test
