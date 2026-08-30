local class = require("class")
local Observable = require("Observable")

---@alias rizu.ai.ChatEntryRole "user"|"assistant"|"tool"|"error"
---@alias rizu.ai.ToolEntryStatus "running"|"success"|"error"|"canceled"

---@class rizu.ai.ChatEntry
---@field role rizu.ai.ChatEntryRole
---@field content string
---@field name string?
---@field tool_call_id string?
---@field arguments string?
---@field status rizu.ai.ToolEntryStatus?

---@class rizu.ai.ChatModel
---@operator call: rizu.ai.ChatModel
---@field agent openai.Agent
---@field system_prompt string
---@field messages openai.Message[]
---@field entries rizu.ai.ChatEntry[]
---@field observable util.Observable
---@field busy boolean
---@field active boolean
---@field request_id integer
---@field request_start integer?
---@field streaming_entry rizu.ai.ChatEntry?
---@field tool_entries {[string]: rizu.ai.ChatEntry}
---@field max_history_chars integer
---@field max_entries integer
---@field auth openai.SubscriptionAuth?
---@field provider_manager rizu.ai.ProviderManager?
local ChatModel = class()

ChatModel.max_history_chars = 200000
ChatModel.max_entries = 200

---@param agent openai.Agent
---@param system_prompt string
---@param options {max_history_chars: integer?, max_entries: integer?, auth: openai.SubscriptionAuth?, provider_manager: rizu.ai.ProviderManager?}?
function ChatModel:new(agent, system_prompt, options)
	options = options or {}
	self.agent = agent
	self.system_prompt = system_prompt
	self.max_history_chars = options.max_history_chars or self.max_history_chars
	self.max_entries = options.max_entries or self.max_entries
	self.provider_manager = options.provider_manager
	self.auth = options.auth or (self.provider_manager and self.provider_manager:getAuth())
	self.observable = Observable()
	self.entries = {}
	self.tool_entries = {}
	self.messages = {}
	self.busy = false
	self.active = true
	self.request_id = 0
	self:resetMessages()
	if self.auth then self.auth:onChanged(self) end

	agent.on_tool_call = function(tool_call)
		if not self.active then
			return
		end
		local call_function = tool_call["function"]
		---@type rizu.ai.ChatEntry
		local entry = {
			role = "tool",
			content = "",
			name = call_function.name,
			tool_call_id = tool_call.id,
			arguments = call_function.arguments,
			status = "running",
		}
		self.tool_entries[tool_call.id] = entry
		self:addEntryObject(entry)
	end
	agent.on_tool_result = function(tool_call, content, is_error)
		if not self.active then
			return
		end
		local entry = self.tool_entries[tool_call.id]
		if not entry then
			local call_function = tool_call["function"]
			entry = {
				role = "tool",
				content = "",
				name = call_function.name,
				tool_call_id = tool_call.id,
				arguments = call_function.arguments,
			}
			self.tool_entries[tool_call.id] = entry
			self:addEntryObject(entry)
		end
		entry.content = content
		entry.status = is_error and "error" or "success"
		self:emitChanged()
	end
end

---@param auth openai.SubscriptionAuth?
function ChatModel:setAuth(auth)
	if self.auth == auth then return end
	if self.auth then self.auth:offChanged(self) end
	self.auth = auth
	if self.auth then self.auth:onChanged(self) end
end

---@return rizu.ai.ModelOption[]
function ChatModel:getModelOptions()
	return self.provider_manager and self.provider_manager.options or {}
end

---@return integer
function ChatModel:getSelectedModelIndex()
	return self.provider_manager and self.provider_manager.selected_index or 0
end

---@return string
function ChatModel:getSelectedModelLabel()
	local manager = self.provider_manager
	return manager and manager:getSelectedOption().label or ""
end

---@param index integer
---@return boolean
---@return string?
function ChatModel:selectModel(index)
	if self.busy then return false, "cannot switch model while a request is running" end
	local manager = self.provider_manager
	if not manager then return false, "model selection is not configured" end
	if index == manager.selected_index then return true end
	local client, auth = manager:select(index)
	self.agent:setClient(client)
	self:setAuth(auth)
	self.entries = {}
	self.tool_entries = {}
	self:resetMessages()
	self:emitChanged()
	return true
end

---@param event table
function ChatModel:receive(event)
	if event.type == "ai_auth_changed" then self:emitChanged() end
end

---@return boolean
function ChatModel:hasAuth()
	return self.auth ~= nil
end

---@return openai.SubscriptionAuthStatus?
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
		self:insertEntry(entry)
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

		---@type openai.ToolCall[]?
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
			---@cast tool_calls openai.ToolCall[]
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
	self:addEntryObject({role = role, content = content, name = name})
end

---@param entry rizu.ai.ChatEntry
function ChatModel:insertEntry(entry)
	table.insert(self.entries, entry)
	while #self.entries > self.max_entries do
		local removed = table.remove(self.entries, 1)
		if removed.tool_call_id then
			self.tool_entries[removed.tool_call_id] = nil
		end
	end
end

---@param entry rizu.ai.ChatEntry
function ChatModel:addEntryObject(entry)
	self:insertEntry(entry)
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
	self.tool_entries = {}
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
	for _, entry in pairs(self.tool_entries) do
		if entry.status == "running" then
			entry.status = "canceled"
		end
	end
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
	if self.auth then self.auth:offChanged(self) end
	if self.provider_manager then
		self.provider_manager:unload()
	elseif self.auth then
		self.auth:unload()
	end
	self:emitChanged()
end

return ChatModel
