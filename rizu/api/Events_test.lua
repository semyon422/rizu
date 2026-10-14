local Events = require("rizu.api.Events")

local test = {}

---@param t testing.T
function test.unsubscribing_during_emit_does_not_skip_a_listener(t)
	local events = Events()
	local calls = {}
	local off
	off = events:on("e", function() calls[#calls + 1] = "once"; off() end)
	events:on("e", function() calls[#calls + 1] = "second" end)

	events:emit("e")
	events:emit("e")
	t:tdeq(calls, {"once", "second", "second"})
end

---@param t testing.T
function test.a_throwing_listener_does_not_stop_the_others(t)
	local events = Events()
	local called = false
	events:on("e", function() error("boom") end)
	events:on("e", function(a) called = a end)

	local print_ = print
	print = function() end
	events:emit("e", 5)
	print = print_
	t:eq(called, 5)
end

---@param t testing.T
function test.remove_listeners_forgets_everything(t)
	local events = Events()
	local count = 0
	local off = events:on("e", function() count = count + 1 end)
	events:removeListeners()
	events:emit("e")
	off()
	t:eq(count, 0)
end

return test
