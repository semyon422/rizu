local AsyncVideoThreadTransport = require("rizu.preview.AsyncVideoThreadTransport")
local ThreadPool = require("thread.ThreadPool")

local test = {}

local function makeChannel()
	return {
		cleared = false,
		pushed = {},
		clear = function(self)
			self.cleared = true
		end,
		push = function(self, event)
			table.insert(self.pushed, event)
		end,
		pop = function()
			return nil
		end,
	}
end

local function installFakeLoveThread()
	local old_love = love
	local input_channel = makeChannel()
	local output_channel = makeChannel()
	local fake_thread = {
		running = false,
		start_args = nil,
		start = function(self, ...)
			self.running = true
			self.start_args = {...}
		end,
		isRunning = function(self)
			return self.running
		end,
		getError = function()
			return nil
		end,
	}

	_G.love = old_love or {}
	love.thread = {
		getChannel = function(name)
			if name:find("_input_") then
				return input_channel
			end
			return output_channel
		end,
		newThread = function()
			return fake_thread
		end,
	}

	return {
		old_love = old_love,
		input_channel = input_channel,
		output_channel = output_channel,
		fake_thread = fake_thread,
		restore = function(self)
			_G.love = self.old_love
		end,
	}
end

---@param t testing.T
function test.registers_managed_thread_until_worker_stops(t)
	local old_managed_threads = ThreadPool.managedThreads
	ThreadPool.managedThreads = {}
	local fake = installFakeLoveThread()

	local transport = AsyncVideoThreadTransport()
	transport:start("test")

	t:eq(ThreadPool.managedThreads[transport].name, "async video preview test")
	t:tdeq(ThreadPool:getRunningThreadNames(), {"async video preview test"})

	transport:stop()

	t:eq(fake.input_channel.pushed[#fake.input_channel.pushed].type, "stop")
	t:ne(ThreadPool.managedThreads[transport], nil)

	fake.fake_thread.running = false
	t:tdeq(ThreadPool:getRunningThreadNames(), {})
	t:eq(ThreadPool.managedThreads[transport], nil)

	fake:restore()
	ThreadPool.managedThreads = old_managed_threads
end

---@param t testing.T
function test.stop_unregisters_finished_worker_immediately(t)
	local old_managed_threads = ThreadPool.managedThreads
	ThreadPool.managedThreads = {}
	local fake = installFakeLoveThread()

	local transport = AsyncVideoThreadTransport()
	transport:start("test")
	fake.fake_thread.running = false
	transport:stop()

	t:eq(ThreadPool.managedThreads[transport], nil)

	fake:restore()
	ThreadPool.managedThreads = old_managed_threads
end

return test
