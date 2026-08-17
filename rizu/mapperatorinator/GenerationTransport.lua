local class = require("class")
local ThreadPool = require("thread.ThreadPool")

local CHANNEL_PREFIX = "mapperatorinator_generation_"
local next_id = 0

---@class rizu.mapperatorinator.GenerationTransport
---@operator call: rizu.mapperatorinator.GenerationTransport
local GenerationTransport = class()

function GenerationTransport:new()
	self.running = false
end

---@param request rizu.mapperatorinator.GenerationRequest
function GenerationTransport:start(request)
	assert(not self.running, "Mapperatorinator generation is already running")
	next_id = next_id + 1
	local input_name = CHANNEL_PREFIX .. next_id .. "_input"
	local output_name = CHANNEL_PREFIX .. next_id .. "_output"
	self.input_channel = love.thread.getChannel(input_name)
	self.output_channel = love.thread.getChannel(output_name)
	self.input_channel:clear()
	self.output_channel:clear()
	self.thread = love.thread.newThread("rizu/mapperatorinator/GenerationWorker.lua")
	self.input_channel:push(request)
	self.thread:start(input_name, output_name)
	self.running = true
	ThreadPool:registerManagedThread(self, "Mapperatorinator generation", self, false)
end

---@return table? event
function GenerationTransport:pop()
	return self.output_channel and self.output_channel:pop() or nil
end

---@return boolean
function GenerationTransport:isRunning()
	return self.running and self.thread and self.thread:isRunning() or false
end

function GenerationTransport:finish()
	self.running = false
	ThreadPool:unregisterManagedThread(self)
	self.input_channel = nil
	self.output_channel = nil
	self.thread = nil
end

return GenerationTransport
