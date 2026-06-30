local class = require("class")
require("rizu.preview.AsyncVideoProtocol")

---@class rizu.preview.FakeAsyncVideoTransport: rizu.preview.IAsyncVideoTransport
---@operator call: rizu.preview.FakeAsyncVideoTransport
---@field started boolean
---@field stopped boolean
---@field id string?
---@field sent rizu.preview.AsyncVideoInputEvent[]
---@field output rizu.preview.AsyncVideoOutputEvent[]
---@field error_message string?
local FakeAsyncVideoTransport = class()

function FakeAsyncVideoTransport:new()
	self.started = false
	self.stopped = false
	---@type rizu.preview.AsyncVideoInputEvent[]
	self.sent = {}
	---@type rizu.preview.AsyncVideoOutputEvent[]
	self.output = {}
end

---@param id string
function FakeAsyncVideoTransport:start(id)
	self.started = true
	self.stopped = false
	self.id = id
end

---@param event rizu.preview.AsyncVideoInputEvent
function FakeAsyncVideoTransport:send(event)
	table.insert(self.sent, event)
end

---@return rizu.preview.AsyncVideoOutputEvent?
function FakeAsyncVideoTransport:pop()
	return table.remove(self.output, 1)
end

function FakeAsyncVideoTransport:checkError()
	if self.error_message then
		error(self.error_message)
	end
end

---@return boolean
function FakeAsyncVideoTransport:isRunning()
	return self.started and not self.stopped
end

function FakeAsyncVideoTransport:stop()
	self.stopped = true
end

---@param event rizu.preview.AsyncVideoOutputEvent
function FakeAsyncVideoTransport:pushOutput(event)
	table.insert(self.output, event)
end

---@return rizu.preview.AsyncVideoInputEvent?
function FakeAsyncVideoTransport:lastSent()
	return self.sent[#self.sent]
end

return FakeAsyncVideoTransport
