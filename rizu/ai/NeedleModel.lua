local class = require("class")
local NeedleThreadTransport = require("rizu.ai.NeedleThreadTransport")
local NeedleToolRegistry = require("rizu.ai.NeedleToolRegistry")

---@alias rizu.ai.NeedleState "unavailable"|"idle"|"debouncing"|"generating"|"ready"|"error"

---@class rizu.ai.NeedleModel
---@operator call: rizu.ai.NeedleModel
---@field state rizu.ai.NeedleState
---@field query string
---@field streamed_text string
---@field formatted_call string?
---@field error string?
---@field telemetry table?
local NeedleModel = class()

---@param config sphere.NeedleConfig
---@param transport? rizu.ai.NeedleThreadTransport
---@param now? fun(): number
function NeedleModel:new(config, transport, now)
	self.config = config
	self.transport = transport or NeedleThreadTransport()
	self.now = now or (love and love.timer and love.timer.getTime) or os.clock
	self.state = "idle"
	self.query = ""
	self.streamed_text = ""
	self.request_id = 0
	self.started = false
	self.worker_ready = false
end

function NeedleModel:start()
	if self.started then return end
	self.started = true
	local ok, err = pcall(self.transport.start, self.transport, self.config)
	if not ok then
		self.state = "unavailable"
		self.error = tostring(err)
	end
end

---@param tool_set rizu.ai.NeedleToolSet
function NeedleModel:activate(tool_set)
	self:start()
	self.tool_set = tool_set
	self:setQuery("")
end

---@param query string
function NeedleModel:setQuery(query)
	if query == self.query and self.state ~= "ready" and self.state ~= "error" then return end
	if self.active_request_id then
		self.transport:send({type = "cancel", request_id = self.active_request_id})
	end
	self.request_id = self.request_id + 1
	self.active_request_id = nil
	self.query = query
	self.proposal_query = nil
	self.call = nil
	self.formatted_call = nil
	self.streamed_text = ""
	self.error = nil
	self.telemetry = nil
	if query == "" then
		if self.state ~= "unavailable" then self.state = "idle" end
		return
	end
	if self.state == "unavailable" then return end
	self.state = "debouncing"
	self.deadline = self.now() + self.config.debounce_seconds
end

function NeedleModel:sendPending()
	if not self.tool_set or #self.tool_set.tools == 0 then
		self.state = "error"
		self.error = "No Needle tools are available on this screen"
		return
	end
	self.active_request_id = self.request_id
	self.state = "generating"
	self.streamed_text = ""
	self.transport:send({
		type = "generate",
		request_id = self.active_request_id,
		query = self.query,
		tools_json = self.tool_set.tools_json,
		routing_tools_json = self.tool_set.routing_tools_json,
		enqueued_at = self.now(),
	})
end

---@param event table
function NeedleModel:handleEvent(event)
	if event.type == "ready" then
		self.worker_ready = true
		return
	elseif event.type == "unavailable" then
		self.state = "unavailable"
		self.error = event.error
		return
	end
	if event.request_id ~= self.active_request_id then return end
	if event.telemetry then self.telemetry = event.telemetry end
	if event.type == "started" then
		self.state = "generating"
	elseif event.type == "reset" then
		self.streamed_text = event.content or ""
	elseif event.type == "delta" then
		self.streamed_text = self.streamed_text .. (event.content or "")
	elseif event.type == "complete" then
		self.streamed_text = event.content or self.streamed_text
		local call, err = NeedleToolRegistry.parse(self.tool_set, self.streamed_text)
		self.active_request_id = nil
		if not call then
			self.state = "error"
			self.error = err
			return
		end
		self.call = call
		self.proposal_query = self.query
		self.formatted_call = NeedleToolRegistry.format(self.tool_set, call)
		self.state = "ready"
	elseif event.type == "error" then
		self.active_request_id = nil
		self.state = "error"
		self.error = event.error
	elseif event.type == "cancelled" then
		self.active_request_id = nil
		self.state = "idle"
	end
end

function NeedleModel:update()
	if self.state == "debouncing" and self.now() >= self.deadline then self:sendPending() end
	while true do
		local event = self.transport:pop()
		if not event then break end
		self:handleEvent(event)
	end
	local ok, err = pcall(self.transport.checkError, self.transport)
	if not ok then
		self.state = "unavailable"
		self.error = tostring(err)
	end
end

---@return string? summary
function NeedleModel:formatTelemetry()
	local telemetry = self.telemetry
	if not telemetry or not telemetry.total_seconds then return nil end
	local routing_prefill = telemetry.routing_prefill_seconds or 0
	local routing = routing_prefill + (telemetry.routing_decode_seconds or 0)
	local final_prefill = telemetry.final_prefill_seconds or 0
	local final = final_prefill + (telemetry.final_decode_seconds or 0)
	return ("queue %.2fs · route %.2fs (prefill %.2fs) · final %.2fs (prefill %.2fs) · total %.2fs"):format(
		telemetry.queue_seconds or 0,
		routing,
		routing_prefill,
		final,
		final_prefill,
		telemetry.total_seconds
	)
end

---@return boolean executed
---@return string? error_message
function NeedleModel:execute()
	if self.state ~= "ready" or not self.call or self.proposal_query ~= self.query then
		return false, "Wait for a valid call for the current query"
	end
	local ok, err = pcall(NeedleToolRegistry.execute, self.tool_set, self.call)
	if not ok then
		self.state = "error"
		self.error = tostring(err)
		return false, self.error
	end
	return true
end

function NeedleModel:cancel()
	if self.active_request_id then self.transport:send({type = "cancel", request_id = self.active_request_id}) end
	self.request_id = self.request_id + 1
	self.active_request_id = nil
	self.query = ""
	self.streamed_text = ""
	self.call = nil
	self.formatted_call = nil
	self.telemetry = nil
	if self.state ~= "unavailable" then self.state = "idle" end
end

function NeedleModel:unload()
	self:cancel()
	if self.started then self.transport:stop() end
	self.started = false
end

return NeedleModel
