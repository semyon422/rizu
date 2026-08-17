local GenerationTransport = require("rizu.mapperatorinator.GenerationTransport")
local ThreadPool = require("thread.ThreadPool")

local test = {}

local function makeChannel()
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
	local channels = {}
	local running = true
	local worker_path
	local started_args
	love.thread = {
		getChannel = function(name)
			channels[name] = channels[name] or makeChannel()
			return channels[name]
		end,
		newThread = function(path)
			worker_path = path
			return {
				start = function(_, ...) started_args = {...} end,
				isRunning = function() return running end,
			}
		end,
	}

	local transport = GenerationTransport()
	local request = {audio_path = "a", output_path = "b"}
	transport:start(request) ---@diagnostic disable-line
	t:eq(worker_path, "rizu/mapperatorinator/GenerationWorker.lua")
	t:eq(#started_args, 2)
	t:eq(channels[started_args[1]]:pop(), request)
	t:ne(ThreadPool.managedThreads[transport], nil)
	channels[started_args[2]]:push({type = "complete"})
	t:eq(transport:pop().type, "complete")
	running = false
	transport:finish()
	t:eq(ThreadPool.managedThreads[transport], nil)

	love.thread = old_thread
	_G.love = old_love
	ThreadPool.managedThreads = old_managed
end

return test
