local class = require("class")
local ThreadPool = require("thread.ThreadPool")

---@class rizu.ai.NeedleThreadTransport
---@operator call: rizu.ai.NeedleThreadTransport
local NeedleThreadTransport = class()

---@param config sphere.NeedleConfig
function NeedleThreadTransport:start(config)
	self.input_channel = love.thread.getChannel("needle_input")
	self.output_channel = love.thread.getChannel("needle_output")
	self.input_channel:clear()
	self.output_channel:clear()
	self.thread = love.thread.newThread("rizu/ai/NeedleWorker.lua")
	self.thread:start("needle_input", "needle_output", config.model_path, config.max_new_tokens)
	ThreadPool:registerManagedThread(self, "Needle inference", self, true)
end

---@param event table
function NeedleThreadTransport:send(event)
	if self.input_channel then self.input_channel:push(event) end
end

---@return table?
function NeedleThreadTransport:pop()
	return self.output_channel and self.output_channel:pop() or nil
end

function NeedleThreadTransport:checkError()
	if not self.thread then return end
	local err = self.thread:getError()
	if err then error(err) end
end

---@return boolean
function NeedleThreadTransport:isRunning()
	return self.thread and self.thread:isRunning() or false
end

function NeedleThreadTransport:stop()
	if self.input_channel then self.input_channel:push({type = "stop"}) end
	if not self:isRunning() then ThreadPool:unregisterManagedThread(self) end
	self.input_channel = nil
	self.output_channel = nil
end

return NeedleThreadTransport
