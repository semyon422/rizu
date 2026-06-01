--- Player registry.
---
--- Accepts an optional `web.ISharedDict` for cross-worker persistence.
--- When a dict is provided, player data is stored as flat JSON-compatible
--- tables keyed by `"p:<token>"`, `"pid:<id>"`, `"pname:<safe_name>"`.
--- Packet queues use dict list ops with key `"pq:<token>"`.
--- When no dict is provided, falls back to in-memory tables (for tests).

local Player = require("bancho.model.Player")
local Privileges = require("bancho.constants.Privileges")
local stbl = require("stbl")

local class = require("class")

---@class bancho.model.PlayerCollection
---@operator call: bancho.model.PlayerCollection
---@field _dict? web.ISharedDict
---@field _matches? bancho.model.MatchCollection
---@field _cache {[integer]: bancho.model.Player} per-request cache (dict mode only)
---@field _list bancho.model.Player[]
---@field _by_token {[string]: bancho.model.Player}
---@field _by_id {[integer]: bancho.model.Player}
---@field _by_name {[string]: bancho.model.Player}
local PlayerCollection = class()

---@param dict? web.ISharedDict Shared dict for cross-worker persistence
function PlayerCollection:new(dict)
	self._dict = dict
	self._cache = {}
	self._list = {}
	self._by_token = {}
	self._by_id = {}
	self._by_name = {}
	return self
end

--- Get a player by token, id, or name.
--- For dict-backed collections, results are cached per-request.
---@param token string?
---@param id integer?
---@param name string?
---@return bancho.model.Player?
function PlayerCollection:get(token, id, name)
	if self._dict then
		-- Check cache first (canonical key is player id)
		if id ~= nil and self._cache[id] then
			return self._cache[id]
		end

		local key
		if token ~= nil then
			key = "p:" .. token
		elseif id ~= nil then
			key = "pid:" .. tostring(id)
		elseif name ~= nil then
			key = "pname:" .. name:lower():gsub(" ", "_"):gsub("[^a-z0-9_]", "_")
		end

		if key then
			local encoded = self._dict:get(key)
			if encoded then
				local data = stbl.decode(encoded)
				if data then
					local player = Player:fromData(data, self)
					self._cache[player.id] = player
					return player
				end
			end
			return nil
		end
	end

	-- In-memory fallback
	if token ~= nil then
		return self._by_token[token]
	end
	if id ~= nil then
		return self._by_id[id]
	end
	if name ~= nil then
		return self._by_name[name:lower():gsub(" ", "_"):gsub("[^a-z0-9_]", "_")]
	end
	return nil
end

--- Add a player to the collection.
---@param player bancho.model.Player
function PlayerCollection:add(player)
	if self._dict then
		local encoded = stbl.encode(player:toData())
		self._dict:set("p:" .. player.token, encoded)
		self._dict:set("pid:" .. player.id, encoded)
		self._dict:set("pname:" .. player.safe_name, encoded)
		self._cache[player.id] = player
		return
	end

	-- In-memory fallback
	if self._by_id[player.id] ~= nil then return end

	table.insert(self._list, player)
	self._by_token[player.token] = player
	self._by_id[player.id] = player
	self._by_name[player.safe_name] = player
end

--- Remove a player from the collection.
---@param player bancho.model.Player
function PlayerCollection:remove(player)
	if self._dict then
		self._dict:delete("p:" .. player.token)
		self._dict:delete("pid:" .. player.id)
		self._dict:delete("pname:" .. player.safe_name)
		self._dict:delete("pq:" .. player.token)
		self._cache[player.id] = nil
		return
	end

	-- In-memory fallback
	if self._by_id[player.id] == nil then return end

	for i = 1, #self._list do
		if self._list[i] == player then
			table.remove(self._list, i)
			break
		end
	end

	self._by_token[player.token] = nil
	self._by_id[player.id] = nil
	self._by_name[player.safe_name] = nil
end

--- Get the set of current player IDs.
---@return {[integer]: true}
function PlayerCollection:ids()
	if self._dict then
		---@type {[integer]: true}
		local ids = {}
		for _, player in ipairs(self:all()) do
			ids[player.id] = true
		end
		return ids
	end

	---@type {[integer]: true}
	local ids = {}
	for _, p in ipairs(self._list) do
		ids[p.id] = true
	end
	return ids
end

--- Get all staff players online.
---@return bancho.model.Player[]
function PlayerCollection:staff()
	if self._dict then
		---@type bancho.model.Player[]
		local result = {}
		for _, player in ipairs(self:all()) do
			if bit.band(player.priv, Privileges.STAFF) ~= 0 then
				table.insert(result, player)
			end
		end
		return result
	end

	---@type bancho.model.Player[]
	local result = {}
	for _, p in ipairs(self._list) do
		if bit.band(p.priv, Privileges.STAFF) ~= 0 then
			table.insert(result, p)
		end
	end
	return result
end

--- Enqueue data to all players except those in the immune list.
--- For dict-backed collections, appends to each player's dict packet queue.
--- For in-memory collections, calls Player:enqueue() directly.
---@param data string
---@param immune? bancho.model.Player[]
function PlayerCollection:enqueue(data, immune)
	if self._dict then
		for _, player in ipairs(self:all()) do
			local skip = false
			if immune then
				for _, imp in ipairs(immune) do
					if player.id == imp.id then
						skip = true
						break
					end
				end
			end
			if not skip then
				self._dict:rpush("pq:" .. player.token, data)
			end
		end
		return
	end

	for _, p in ipairs(self._list) do
		local skip = false
		if immune then
			for _, imp in ipairs(immune) do
				if p.id == imp.id then
					skip = true
					break
				end
			end
		end
		if not skip then
			p:enqueue(data)
		end
	end
end

--- Drain all queued packets for a player from the dict packet queue.
--- Returns concatenated packet data or nil if empty.
--- Only valid for dict-backed collections.
---@param token string
---@return string?
function PlayerCollection:drain_packets(token)
	if not self._dict then
		return nil
	end

	---@type string[]
	local packets = {}
	while true do
		local pkt = self._dict:lpop("pq:" .. token)
		if not pkt then
			break
		end
		table.insert(packets, pkt)
	end

	if #packets == 0 then
		return nil
	end

	return table.concat(packets)
end

--- Write back all cached objects to the shared dict.
--- Called at end of request to persist mutations.
--- Uses :replace() to avoid resurrecting objects deleted by other workers.
--- Clears the cache after flushing.
function PlayerCollection:flush()
	if not self._dict then return end

	for _, player in pairs(self._cache) do
		local encoded = stbl.encode(player:toData())
		-- :replace() only writes if the key already exists
		-- This prevents resurrecting players deleted by another worker
		self._dict:replace("p:" .. player.token, encoded)
		self._dict:replace("pid:" .. player.id, encoded)
		self._dict:replace("pname:" .. player.safe_name, encoded)
	end
	self._cache = {}
end

--- Return the list of all players.
--- For dict-backed collections, iterates dict keys and deserializes.
--- Cross-references (match, spectating) are NOT resolved to avoid circular
--- deserialization. Use :get() for individual lookups that need full resolution.
---@return bancho.model.Player[]
function PlayerCollection:all()
	if self._dict then
		---@type bancho.model.Player[]
		local result = {}
		local keys = self._dict:get_keys(1000)
		for _, key in ipairs(keys) do
			if type(key) == "string" and key:sub(1, 2) == "p:" then
				local encoded = self._dict:get(key)
				if encoded then
					local data = stbl.decode(encoded)
					if data then
						-- Don't pass collection to avoid circular Player->Match->Player deserialization
						table.insert(result, Player:fromData(data))
					end
				end
			end
		end
		return result
	end

	return self._list
end

--- Return the number of players.
---@return integer
function PlayerCollection:len()
	if self._dict then
		return #self:all()
	end
	return #self._list
end

--- Set the match collection for resolving cross-references.
---@param matches bancho.model.MatchCollection
function PlayerCollection:setMatches(matches)
	self._matches = matches
end

--- Get a match by id (for resolving Player.match cross-references).
---@param id integer
---@return bancho.model.Match?
function PlayerCollection:getMatch(id)
	if self._matches then
		return self._matches:get(id)
	end
	return nil
end

return PlayerCollection
