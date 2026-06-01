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
---@field _players? bancho.model.PlayerCollection
---@field _cache {[integer]: bancho.model.Match} per-request cache (dict mode only)
---@field _matches {[integer]: bancho.model.Match?}
---@field max_matches integer
local MatchCollection = class()

---@param dict? web.ISharedDict Shared dict for cross-worker persistence
---@param max_matches? integer Maximum concurrent multiplayer rooms
function MatchCollection:new(dict, max_matches)
	self._dict = dict
	self._cache = {}
	self.max_matches = max_matches or 64
	self._matches = {}
	for i = 1, self.max_matches do
		self._matches[i] = nil
	end
	return self
end

--- Get a match by id.
--- For dict-backed collections, results are cached per-request.
---@param id integer
---@return bancho.model.Match?
function MatchCollection:get(id)
	if id < 1 or id > self.max_matches then
		return nil
	end

	if self._dict then
		-- Check cache first
		if self._cache[id] then
			return self._cache[id]
		end

		local encoded = self._dict:get("m:" .. id)
		if encoded then
			local data = stbl.decode(encoded)
			if data and not data.reserved then
				-- Skip placeholder entries (not yet flushed)
				local match = Match:fromData(data, self._players)
				self._cache[id] = match
				return match
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
--- For dict-backed collections, reserves the slot atomically then defers persistence to flush.
--- This ensures the match is persisted with all its players/slots fully initialized.
---@param match bancho.model.Match
---@return boolean success true on success, false if another worker claimed the slot
function MatchCollection:add(match)
	if self._dict then
		-- Reserve the slot atomically with a placeholder
		local ok, err = self._dict:add("m:" .. match.id, stbl.encode({reserved = true}))
		if not ok and err == "exists" then
			return false
		end
		self._cache[match.id] = match
		return true
	end

	self._matches[match.id] = match
	return true
end

--- Remove a match.
---@param match bancho.model.Match?
function MatchCollection:remove(match)
	if match == nil then return end

	if self._dict then
		self._dict:delete("m:" .. match.id)
		self._cache[match.id] = nil
		return
	end

	self._matches[match.id] = nil
end

--- Return all active matches.
--- Cross-references (slot players) are NOT resolved to avoid circular
--- deserialization. Use :get() for individual lookups that need full resolution.
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
					if data and not data.reserved then
						-- Skip placeholder entries (not yet flushed)
						-- Don't pass player collection to avoid circular Match->Player->Match deserialization
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

--- Write back all cached objects to the shared dict.
--- Called at end of request to persist mutations.
--- Uses :replace() to avoid resurrecting objects deleted by other workers.
--- Clears the cache after flushing.
function MatchCollection:flush()
	if not self._dict then return end

	for _, match in pairs(self._cache) do
		-- :replace() only writes if the key already exists
		-- This prevents resurrecting matches deleted by another worker
		self._dict:replace("m:" .. match.id, stbl.encode(match:toData()))
	end
	self._cache = {}
end

--- Set the player collection for resolving cross-references.
---@param players bancho.model.PlayerCollection
function MatchCollection:setPlayers(players)
	self._players = players
end

return MatchCollection
