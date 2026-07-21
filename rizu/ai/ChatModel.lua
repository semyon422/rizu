local class = require("class")
local Observable = require("Observable")

---@alias rizu.ai.ChatEntryRole "user"|"assistant"|"tool"|"error"

---@class rizu.ai.ChatEntry
---@field role rizu.ai.ChatEntryRole
---@field content string
---@field name string?

---@class rizu.ai.ChatModel
---@operator call: rizu.ai.ChatModel
---@field agent aqua.openai.Agent
---@field system_prompt string
---@field messages aqua.openai.Message[]
---@field entries rizu.ai.ChatEntry[]
---@field observable util.Observable
---@field busy boolean
---@field active boolean
---@field request_id integer
---@field request_start integer?
---@field streaming_entry rizu.ai.ChatEntry?
---@field max_history_chars integer
---@field max_entries integer
---@field auth aqua.openai.SubscriptionAuth?
local ChatModel = class()

ChatModel.max_history_chars = 200000
ChatModel.max_entries = 200

---@param agent aqua.openai.Agent
---@param system_prompt string
---@param options {max_history_chars: integer?, max_entries: integer?, auth: aqua.openai.SubscriptionAuth?}?
function ChatModel:new(agent, system_prompt, options)
	options = options or {}
	self.agent = agent
	self.system_prompt = system_prompt
	self.max_history_chars = options.max_history_chars or self.max_history_chars
	self.max_entries = options.max_entries or self.max_entries
	self.auth = options.auth
	self.observable = Observable()
	self.entries = {}
	self.messages = {}
	self.busy = false
	self.active = true
	self.request_id = 0
	self:resetMessages()
	if self.auth then self.auth:onChanged(self) end

	agent.on_tool_result = function(tool_call, content)
		if not self.active then
			return
		end
		self:addEntry("tool", content, tool_call["function"].name)
	end
end

---@param event table
function ChatModel:receive(event)
	if event.type == "ai_auth_changed" then self:emitChanged() end
end

---@return boolean
function ChatModel:hasAuth()
	return self.auth ~= nil
end

---@return aqua.openai.SubscriptionAuthStatus?
---@return string?
function ChatModel:getAuthStatus()
	if not self.auth then return end
	return self.auth.status, self.auth.error
end

---@return boolean
---@return string?
function ChatModel:startLogin()
	if not self.auth then return false, "OpenAI subscription login is not configured" end
	return self.auth:startLogin()
end

---@param content string
function ChatModel:appendAssistantDelta(content)
	if not self.streaming_entry then
		---@type rizu.ai.ChatEntry
		local entry = {role = "assistant", content = ""}
		self.streaming_entry = entry
		table.insert(self.entries, entry)
		while #self.entries > self.max_entries do
			table.remove(self.entries, 1)
		end
	end
	self.streaming_entry.content = self.streaming_entry.content .. content
	self:emitChanged()
end

function ChatModel:removeActiveProtocolMessages()
	if not self.request_start then
		return
	end
	for i = #self.messages, self.request_start, -1 do
		table.remove(self.messages, i)
	end
	self.request_start = nil
end

function ChatModel:removeIncompleteActiveProtocolMessages()
	local request_start = self.request_start
	if not request_start then
		return
	end

	local complete_end = request_start
	local index = request_start + 1
	while index <= #self.messages do
		local message = self.messages[index]
		if message.role ~= "assistant" then
			break
		end

		local tool_calls = message.tool_calls
		if type(tool_calls) ~= "table" or #tool_calls == 0 then
			if type(message.content) == "string" then
				complete_end = index
				index = index + 1
			else
				break
			end
		else
			local group_complete = true
			for offset, tool_call in ipairs(tool_calls) do
				local tool_message = self.messages[index + offset]
				if
				type(tool_call.id) ~= "string" or
				not tool_message or
				tool_message.role ~= "tool" or
				tool_message.tool_call_id ~= tool_call.id
				then
					group_complete = false
					break
				end
			end
			if not group_complete then
				break
			end
			complete_end = index + #tool_calls
			index = complete_end + 1
		end
	end

	for i = #self.messages, complete_end + 1, -1 do
		table.remove(self.messages, i)
	end
	self.request_start = nil
end

function ChatModel:resetMessages()
	self.messages = {{role = "system", content = self.system_prompt}}
end

---@param observer function|table
function ChatModel:onChanged(observer)
	self.observable:add(observer)
end

---@param observer function|table
function ChatModel:offChanged(observer)
	self.observable:remove(observer)
end

function ChatModel:emitChanged()
	self.observable:send({type = "chat_changed"})
end

---@param role rizu.ai.ChatEntryRole
---@param content string
---@param name string?
function ChatModel:addEntry(role, content, name)
	table.insert(self.entries, {role = role, content = content, name = name})
	while #self.entries > self.max_entries do
		table.remove(self.entries, 1)
	end
	self:emitChanged()
end

---@return integer
function ChatModel:getHistorySize()
	local size = 0
	for _, message in ipairs(self.messages) do
		size = size + #(message.content or "")
	end
	return size
end

function ChatModel:trimHistory()
	while #self.messages > 2 and self:getHistorySize() > self.max_history_chars do
		table.remove(self.messages, 2)
		while self.messages[2] and self.messages[2].role ~= "user" do
			table.remove(self.messages, 2)
		end
	end
end

function ChatModel:clear()
	if self.busy then
		return false
	end
	self.entries = {}
	self:resetMessages()
	self:emitChanged()
	return true
end

---@param content string
---@return boolean
---@return string?
function ChatModel:send(content)
	if self.busy then
		return false, "a request is already running"
	end
	if content:match("^%s*$") then
		return false, "message is empty"
	end
	if self.auth and not self.auth:isAuthenticated() then
		return false, "OpenAI login is required"
	end

	self.busy = true
	self.request_id = self.request_id + 1
	local request_id = self.request_id
	self.request_start = #self.messages + 1
	self.streaming_entry = nil
	table.insert(self.messages, {role = "user", content = content})
	self:addEntry("user", content)

	coroutine.wrap(function()
		local ok, message, err = xpcall(function()
			return self.agent:run(self.messages, function(delta)
				if self.active and self.busy and self.request_id == request_id then
					self:appendAssistantDelta(delta)
				end
			end)
		end, debug.traceback)
		if not self.active or self.request_id ~= request_id then
			return
		end
		self.busy = false
		if not ok then
			self:removeIncompleteActiveProtocolMessages()
			self:addEntry("error", tostring(message))
		elseif not message then
			self:removeIncompleteActiveProtocolMessages()
			self:addEntry("error", err or "AI request failed")
		else
			self.request_start = nil
			if self.streaming_entry then
				self.streaming_entry.content = assert(message.content)
			else
				self:addEntry("assistant", assert(message.content))
			end
		end
		self.streaming_entry = nil
		self:trimHistory()
		self:emitChanged()
	end)()
	return true
end

---@return boolean
function ChatModel:cancel()
	if not self.busy then
		return false
	end
	self.request_id = self.request_id + 1
	self.busy = false
	self.agent:cancel()
	self:removeActiveProtocolMessages()
	self.streaming_entry = nil
	self:emitChanged()
	return true
end

function ChatModel:unload()
	if self.busy then
		self:cancel()
	end
	self.active = false
	if self.auth then
		self.auth:offChanged(self)
		self.auth:unload()
	end
	self:emitChanged()
end

return ChatModel
