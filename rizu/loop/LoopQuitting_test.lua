local delay = require("delay")
local thread = require("thread")
local ThreadRemote = require("threadremote.ThreadRemote")
local LoopQuitting = require("rizu.loop.LoopQuitting")

local test = {}

---@param t testing.T
function test.preserves_restart_exit_code(t)
	local old_love = love
	local old_unload = thread.unload
	local old_thread_update = thread.update
	local old_remote_update = ThreadRemote.updateAll
	local old_delay_update = delay.update
	local old_running_names = thread.ThreadPool.getRunningThreadNames

	_G.love = {
		event = {
			pump = function() end,
			poll = function() return function() end end,
		},
	}
	thread.unload = function() end
	thread.update = function() end
	ThreadRemote.updateAll = function() end
	delay.update = function() end
	thread.ThreadPool.getRunningThreadNames = function() return {} end

	local ok, err = xpcall(function()
		local quitting = LoopQuitting({quit_code = "restart"} --[[@as rizu.Loop]])
		t:eq(quitting:update(), "restart")
	end, debug.traceback)

	_G.love = old_love
	thread.unload = old_unload
	thread.update = old_thread_update
	ThreadRemote.updateAll = old_remote_update
	delay.update = old_delay_update
	thread.ThreadPool.getRunningThreadNames = old_running_names
	if not ok then
		error(err)
	end
end

return test
