local class = require("class")
local thread = require("thread")
local delay = require("delay")
local ThreadRemote = require("threadremote.ThreadRemote")

---@class rizu.LoopQuitting
---@operator call: rizu.LoopQuitting
local LoopQuitting = class()

function LoopQuitting:new(loop)
	self.loop = loop
	self.reported_threads = {}
	self.thread_pool_unloaded = false
end

---@return number|string?
function LoopQuitting:update()
	love.event.pump()

	for name in love.event.poll() do
		if name == "quit" then
			return self.loop.quit_code
		end
	end

	if not self.thread_pool_unloaded then
		thread.unload()
		self.thread_pool_unloaded = true
	end

	ThreadRemote.updateAll()
	thread.update()
	delay.update()

	local running_thread_names = thread.ThreadPool:getRunningThreadNames()
	if #running_thread_names == 0 then
		return self.loop.quit_code
	end

	for _, name in ipairs(running_thread_names) do
		if not self.reported_threads[name] then
			self.reported_threads[name] = true
			print("[quit-debug] waiting thread", name)
		end
	end

	if love.graphics and love.graphics.isActive() then
		love.graphics.clear(love.graphics.getBackgroundColor())
		love.graphics.setColor(1, 1, 1, 1)
		local text = "waiting for " .. #running_thread_names .. " threads"
		local y = 0
		love.graphics.printf(text, 0, y, 1000, "left")
		y = y + 20
		for _, name in ipairs(running_thread_names) do
			love.graphics.printf(name, 0, y, 1000, "left")
			y = y + 20
		end
		love.graphics.present()
	end

	love.timer.sleep(0.1)
end

return LoopQuitting
