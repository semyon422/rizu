local class = require("class")
local utf8validate = require("utf8validate")

---@class rizu.ai.ToolFailure
---@field sequence integer
---@field timestamp integer
---@field surface "agent"|"mcp"
---@field tool string?
---@field arguments any
---@field error string

---@class rizu.ai.ToolFailureLog
---@operator call: rizu.ai.ToolFailureLog
---@field entries rizu.ai.ToolFailure[]
---@field max_entries integer
---@field sequence integer
---@field get_time fun(): integer
local ToolFailureLog = class()

---@param options {max_entries: integer?, get_time: (fun(): integer)?}?
function ToolFailureLog:new(options)
	options = options or {}
	self.entries = {}
	self.max_entries = options.max_entries or 100
	self.sequence = 0
	self.get_time = options.get_time or os.time
end

---@param surface "agent"|"mcp"
---@param name string?
---@param arguments any
---@param err string
function ToolFailureLog:add(surface, name, arguments, err)
	self.sequence = self.sequence + 1
	table.insert(self.entries, {
		sequence = self.sequence,
		timestamp = self.get_time(),
		surface = surface,
		tool = name,
		arguments = arguments,
		error = utf8validate(tostring(err)),
	})
	if #self.entries > self.max_entries then
		table.remove(self.entries, 1)
	end
end

---@param limit integer
---@param surface "all"|"agent"|"mcp"
---@return rizu.ai.ToolFailure[]
function ToolFailureLog:list(limit, surface)
	local result = {}
	for index = #self.entries, 1, -1 do
		local entry = self.entries[index]
		if surface == "all" or entry.surface == surface then
			table.insert(result, entry)
			if #result >= limit then break end
		end
	end
	return result
end

return ToolFailureLog
