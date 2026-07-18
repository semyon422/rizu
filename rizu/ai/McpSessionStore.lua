local class = require("class")
local json = require("web.json")

---@class rizu.ai.McpSessionStoreOptions
---@field path string?
---@field max_age number?
---@field max_sessions integer?
---@field get_time (fun(): number)?
---@field read (fun(path: string): string?, string?)?
---@field write (fun(path: string, body: string): true?, string?)?

---@class rizu.ai.McpSessionStore: mcp.SessionStore
---@operator call: rizu.ai.McpSessionStore
---@field path string
---@field max_age number
---@field max_sessions integer
---@field get_time fun(): number
---@field read fun(path: string): string?, string?
---@field write fun(path: string, body: string): true?, string?
---@field sessions {[string]: number}
---@field session_index integer
local McpSessionStore = class()

McpSessionStore.path = "userdata/mcp_sessions.json"
McpSessionStore.max_age = 7 * 24 * 60 * 60
McpSessionStore.max_sessions = 64

---@param options rizu.ai.McpSessionStoreOptions?
function McpSessionStore:new(options)
	options = options or {}
	self.path = options.path or self.path
	self.max_age = options.max_age or self.max_age
	self.max_sessions = options.max_sessions or self.max_sessions
	self.get_time = options.get_time or os.time
	self.read = options.read or function(path)
		if not love.filesystem.getInfo(path, "file") then
			return
		end
		return love.filesystem.read(path)
	end
	self.write = options.write or function(path, body)
		local ok, err = love.filesystem.write(path, body)
		return ok == true and true or nil, err
	end
	self.sessions = {}
	self.session_index = 0
end

---@return true?
---@return string?
function McpSessionStore:save()
	return self.write(self.path, json.encode(self.sessions))
end

---@return string[]?
---@return string?
function McpSessionStore:load()
	local body, read_err = self.read(self.path)
	if not body then
		if read_err then
			return nil, read_err
		end
		self.sessions = {}
		return {}
	end
	local decoded, decode_err = json.decode_safe(body)
	if type(decoded) ~= "table" then
		return nil, "invalid MCP session store: " .. tostring(decode_err)
	end

	local now = self.get_time()
	---@type {id: string, updated_at: number}[]
	local records = {}
	for id, updated_at in pairs(decoded) do
		if type(id) ~= "string" or type(updated_at) ~= "number" then
			return nil, "invalid MCP session store entry"
		end
		if now - updated_at <= self.max_age then
			table.insert(records, {id = id, updated_at = updated_at})
		end
	end
	table.sort(records, function(a, b)
		return a.updated_at > b.updated_at
	end)

	self.sessions = {}
	---@type string[]
	local ids = {}
	for index = 1, math.min(#records, self.max_sessions) do
		local record = records[index]
		self.sessions[record.id] = record.updated_at
		table.insert(ids, record.id)
	end
	local ok, save_err = self:save()
	if not ok then
		return nil, save_err
	end
	return ids
end

---@return string
function McpSessionStore:generateId()
	local id
	repeat
		self.session_index = self.session_index + 1
		id = ("%d-%d"):format(self.get_time(), self.session_index)
	until not self.sessions[id]
	return id
end

---@param id string
---@return true?
---@return string?
function McpSessionStore:add(id)
	self.sessions[id] = self.get_time()

	local count = 0
	local oldest_id
	local oldest_time
	for session_id, updated_at in pairs(self.sessions) do
		count = count + 1
		if not oldest_time or updated_at < oldest_time then
			oldest_id = session_id
			oldest_time = updated_at
		end
	end
	if count > self.max_sessions then
		self.sessions[assert(oldest_id)] = nil
	end
	return self:save()
end

---@param id string
---@return true?
---@return string?
function McpSessionStore:remove(id)
	self.sessions[id] = nil
	return self:save()
end

return McpSessionStore
