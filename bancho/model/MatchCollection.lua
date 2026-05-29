--- Match registry.
---
--- Accepts an optional `web.ISharedDict` for cross-worker persistence.
--- When a dict is provided, match data is stored as flat JSON-compatible
--- tables keyed by `"m:<id>"`.
--- When no dict is provided, falls back to in-memory tables (for tests).

local Match = require("bancho.model.Match")
local stbl = require("stbl")

local class = require("class")

---@class bancho.model.MatchCollection
---@operator call: bancho.model.MatchCollection
---@field _dict? web.ISharedDict
---@field _matches {[integer]: bancho.model.Match?}
---@field max_matches integer
local MatchCollection = class()

---@param dict? web.ISharedDict Shared dict for cross-worker persistence
---@param max_matches? integer Maximum concurrent multiplayer rooms
function MatchCollection:new(dict, max_matches)
	self._dict = dict
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

	if self._dict then
		local encoded = self._dict:get("m:" .. id)
		if encoded then
			local data = stbl.decode(encoded)
			if data then
				return Match:fromData(data)
			end
		end
		return nil
	end

	return self._matches[id]
end

--- Get the first free match id.
---@return integer?
function MatchCollection:getFree()
	for i = 1, self.max_matches do
		if self:get(i) == nil then
			return i
		end
	end
	return nil
end

--- Add a match.
---@param match bancho.model.Match
function MatchCollection:add(match)
	if self._dict then
		self._dict:set("m:" .. match.id, stbl.encode(match:toData()))
		return
	end

	self._matches[match.id] = match
end

--- Remove a match.
---@param match bancho.model.Match?
function MatchCollection:remove(match)
	if match == nil then return end

	if self._dict then
		self._dict:delete("m:" .. match.id)
		return
	end

	self._matches[match.id] = nil
end

--- Return all active matches.
---@return bancho.model.Match[]
function MatchCollection:all()
	---@type bancho.model.Match[]
	local result = {}

	if self._dict then
		local keys = self._dict:get_keys(1000)
		for _, key in ipairs(keys) do
			if type(key) == "string" and key:sub(1, 2) == "m:" then
				local encoded = self._dict:get(key)
				if encoded then
					local data = stbl.decode(encoded)
					if data then
						table.insert(result, Match:fromData(data))
					end
				end
			end
		end
		return result
	end

	for _, m in pairs(self._matches) do
		if m ~= nil then
			table.insert(result, m)
		end
	end
	return result
end

return MatchCollection
