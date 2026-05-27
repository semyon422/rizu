--- In-memory match registry.

local Match = require("bancho.model.Match")

local class = require("class")

---@class bancho.model.MatchCollection
---@field _matches table<integer, bancho.model.Match?>
---@field max_matches integer
local MatchCollection = class()

function MatchCollection:new(max_matches)
	self.max_matches = max_matches or 64
	self._matches = {}
	for i = 1, self.max_matches do
		self._matches[i] = nil
	end
	return self
end

--- Get a match by id.
---@param id integer
---@return bancho.model.Match?
function MatchCollection:get(id)
	if id < 1 or id > self.max_matches then
		return nil
	end
	return self._matches[id]
end

--- Get the first free match id.
---@return integer?
function MatchCollection:getFree()
	for i = 1, self.max_matches do
		if self._matches[i] == nil then
			return i
		end
	end
	return nil
end

--- Add a match.
---@param match bancho.model.Match
function MatchCollection:add(match)
	self._matches[match.id] = match
end

--- Remove a match.
---@param match bancho.model.Match?
function MatchCollection:remove(match)
	if match == nil then return end
	self._matches[match.id] = nil
end

--- Return all active matches.
---@return bancho.model.Match[]
function MatchCollection:all()
	local result = {}
	for _, m in pairs(self._matches) do
		if m ~= nil then
			table.insert(result, m)
		end
	end
	return result
end

return MatchCollection
