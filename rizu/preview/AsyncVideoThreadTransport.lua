local class = require("class")
local AsyncVideoConfig = require("rizu.preview.AsyncVideoConfig")
local ThreadPool = require("thread.ThreadPool")
require("rizu.preview.AsyncVideoProtocol")

---@class rizu.preview.AsyncVideoThreadTransport: rizu.preview.IAsyncVideoTransport
---@operator call: rizu.preview.AsyncVideoThreadTransport
---@field input_channel love.Channel?
---@field output_channel love.Channel?
---@field thread love.Thread?
---@field managed_name string?
local AsyncVideoThreadTransport = class()

---@param id string
function AsyncVideoThreadTransport:start(id)
	local input_channel_name = "async_video_input_" .. id
	local output_channel_name = "async_video_output_" .. id
	self.input_channel = love.thread.getChannel(input_channel_name)
	self.output_channel = love.thread.getChannel(output_channel_name)
	self.input_channel:clear()
	self.output_channel:clear()
	self.thread = love.thread.newThread(AsyncVideoConfig.worker_path)
	self.thread:start(input_channel_name, output_channel_name)
	self.managed_name = "async video preview " .. id
	ThreadPool:registerManagedThread(self, self.managed_name, self, true)
end

---@param event rizu.preview.AsyncVideoInputEvent
function AsyncVideoThreadTransport:send(event)
	if self.input_channel then
		self.input_channel:push(event)
	end
end

---@return rizu.preview.AsyncVideoOutputEvent?
function AsyncVideoThreadTransport:pop()
	return self.output_channel and self.output_channel:pop() or nil
end

function AsyncVideoThreadTransport:checkError()
	if not self.thread then
		return
	end

	local err = self.thread:getError()
	if err then
		error(err)
	end
end

---@return boolean
function AsyncVideoThreadTransport:isRunning()
	return self.thread and self.thread:isRunning() or false
end

function AsyncVideoThreadTransport:stop()
	if self.input_channel then
		self.input_channel:push({type = "stop"})
	end
	if not self:isRunning() then
		ThreadPool:unregisterManagedThread(self)
	end
	self.input_channel = nil
	self.output_channel = nil
end

return AsyncVideoThreadTransport
