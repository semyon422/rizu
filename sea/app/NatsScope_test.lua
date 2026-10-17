local NatsScope = require("sea.app.NatsScope")
local TestNats = require("icc.nats.TestNats")
local table_util = require("table_util")

local test = {}

---@param t testing.T
function test.lazy_and_preserves_results(t)
	local created = 0
	local context = {}
	local scope = NatsScope(function() return context end, function()
		created = created + 1
		return TestNats()
	end)
	local results = table_util.pack(scope:call(function(a, b) return a, b, nil end, 1, 2))
	t:eq(created, 0)
	t:eq(results.n, 3)
	t:eq(results[1], 1)
	t:eq(results[2], 2)
end

---@param t testing.T
function test.closes_on_success_and_error(t)
	for _, crash in ipairs({false, true}) do
		local context = {}
		local nc = TestNats()
		local scope = NatsScope(function() return context end, function() return nc end)
		local delivered = false
		local ok, err = pcall(scope.call, scope, function()
			t:eq(scope:get(), scope:get())
			nc:subscribe("test", function() delivered = true end)
			nc:publish({subject = "test", payload = "pending"})
			if crash then error("scope failure") end
		end)
		t:eq(ok, not crash)
		if crash then t:assert(tostring(err):find("scope failure", 1, true)) end
		t:eq(context.rizu_nats, nil)
		t:eq(#nc.subscribers, 0)
		nc:flush()
		t:eq(delivered, false)
	end
end

---@param t testing.T
function test.concurrent_contexts_and_yield(t)
	---@type {[thread]: sea.NatsScopeContext}
	local contexts = {}
	local scope = NatsScope(function() return contexts[coroutine.running()] end, function() return TestNats() end)
	local function work()
		scope:call(function()
			local nc = scope:get()
			nc:subscribe("test", function() end)
			coroutine.yield(nc)
			t:eq(scope:get(), nc)
		end)
	end
	local first = coroutine.create(work)
	local second = coroutine.create(work)
	contexts[first] = {}
	contexts[second] = {}
	local ok1, nc1 = coroutine.resume(first)
	local ok2, nc2 = coroutine.resume(second)
	t:assert(ok1 and ok2)
	t:ne(nc1, nc2)
	t:assert(coroutine.resume(first))
	t:eq(contexts[first].rizu_nats, nil)
	t:eq(contexts[second].rizu_nats, nc2)
	t:assert(coroutine.resume(second))
	t:eq(contexts[second].rizu_nats, nil)
end

---@param t testing.T
function test.timer_contexts_and_original_context_cleanup(t)
	---@type sea.NatsScopeContext
	local context = {}
	local original = context
	local scope = NatsScope(function() return context end, function() return TestNats() end)
	local next_context = {}
	scope:call(function(premature)
		t:eq(premature, false)
		scope:get()
		context = next_context
		scope:get()
	end, false)
	t:eq(original.rizu_nats, nil)
	t:ne(next_context.rizu_nats, nil)
	scope:call(function() end)
	t:eq(next_context.rizu_nats, nil)
end

return test
