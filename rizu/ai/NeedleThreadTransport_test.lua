local NeedleThreadTransport = require("rizu.ai.NeedleThreadTransport")
local ThreadPool = require("thread.ThreadPool")

local test = {}

---@class rizu.ai.FakeNeedleChannel
---@field clear fun(self: rizu.ai.FakeNeedleChannel)
---@field push fun(self: rizu.ai.FakeNeedleChannel, value: table)
---@field pop fun(self: rizu.ai.FakeNeedleChannel): table?

---@return rizu.ai.FakeNeedleChannel
local function makeChannel()
	---@type table[]
	local values = {}
	return {
		clear = function() values = {} end,
		push = function(_, value) values[#values + 1] = value end,
		pop = function() return table.remove(values, 1) end,
	}
end

---@param t testing.T
function test.managed_lifecycle(t)
	local old_love = love
	_G.love = love or {}
	local old_thread = love.thread
	local old_managed = ThreadPool.managedThreads
	ThreadPool.managedThreads = {}
	local input = makeChannel()
	local output = makeChannel()
	local running = true
	---@type unknown[]?
	local started_args
	love.thread = {
		getChannel = function(name) return name == "needle_input" and input or output end,
		newThread = function(path)
			t:eq(path, "rizu/ai/NeedleWorker.lua")
			return {
				start = function(_, ...) started_args = {...} end,
				isRunning = function() return running end,
				getError = function() end,
			}
		end,
	}

	local transport = NeedleThreadTransport()
	transport:start({model_path = "model.bin", max_new_tokens = 64, debounce_seconds = 0})
	t:tdeq(started_args, {"needle_input", "needle_output", "model.bin", 64})
	t:ne(ThreadPool.managedThreads[transport], nil)
	running = false
	transport:stop()
	t:eq(input:pop().type, "stop")
	t:eq(ThreadPool.managedThreads[transport], nil)

	love.thread = old_thread
	_G.love = old_love
	ThreadPool.managedThreads = old_managed
end

return test
