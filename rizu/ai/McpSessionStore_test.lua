local json = require("web.json")
local McpSessionStore = require("rizu.ai.McpSessionStore")

local test = {}

---@param t testing.T
function test.loads_prunes_and_updates_sessions(t)
	local body = json.encode({active = 90, second = 80, third = 70, expired = 10})
	local store = McpSessionStore({
		max_age = 50,
		max_sessions = 2,
		get_time = function() return 100 end,
		read = function() return body end,
		write = function(_, value)
			body = value
			return true
		end,
	})

	local ids = assert(store:load())
	t:eq(#ids, 2)
	t:eq(store.sessions.active, 90)
	t:eq(store.sessions.second, 80)
	t:eq(store.sessions.third, nil)
	t:eq(store.sessions.expired, nil)
	store.sessions["100-1"] = 100
	t:eq(store:generateId(), "100-2")
	store.sessions["100-1"] = nil

	t:assert(store:add("new"))
	t:eq(store.sessions.new, 100)
	t:eq(store.sessions.active, 90)
	t:eq(store.sessions.second, nil)
	t:assert(store:remove("active"))
	t:eq(store.sessions.active, nil)
	t:tdeq(json.decode(body), {new = 100})
end

---@param t testing.T
function test.missing_store_is_empty(t)
	local store = McpSessionStore({
		read = function() return nil end,
		write = function() return true end,
	})
	t:tdeq(assert(store:load()), {})
end

return test
