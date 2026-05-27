--- In-memory player registry indexed by token, ID, and name.

local Player = require("bancho.model.Player")
local Privileges = require("bancho.constants.Privileges")

local class = require("class")

---@class bancho.model.PlayerCollection
---@field _list bancho.model.Player[]
---@field _by_token table<string, bancho.model.Player>
---@field _by_id table<integer, bancho.model.Player>
---@field _by_name table<string, bancho.model.Player>
local PlayerCollection = class()

function PlayerCollection:new()
	self._list = {}
	self._by_token = {}
	self._by_id = {}
	self._by_name = {}
	return self
end

--- Get a player by token, id, or name.
---@param token? string
---@param id? integer
---@param name? string
---@return bancho.model.Player?
function PlayerCollection:get(token, id, name)
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
	if self._by_id[player.id] ~= nil then return end

	table.insert(self._list, player)
	self._by_token[player.token] = player
	self._by_id[player.id] = player
	self._by_name[player.safe_name] = player
end

--- Remove a player from the collection.
---@param player bancho.model.Player
function PlayerCollection:remove(player)
	if self._by_id[player.id] == nil then return end

	-- Remove from list
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
---@return table<integer, true>
function PlayerCollection:ids()
	local ids = {}
	for _, p in ipairs(self._list) do
		ids[p.id] = true
	end
	return ids
end

--- Get all staff players online.
---@return bancho.model.Player[]
function PlayerCollection:staff()
	local result = {}
	for _, p in ipairs(self._list) do
		if bit.band(p.priv, Privileges.STAFF) ~= 0 then
			table.insert(result, p)
		end
	end
	return result
end

--- Enqueue data to all players except those in the immune list.
---@param data string
---@param immune? bancho.model.Player[]
function PlayerCollection:enqueue(data, immune)
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

--- Return the list of all players.
---@return bancho.model.Player[]
function PlayerCollection:all()
	return self._list
end

--- Return the number of players.
---@return integer
function PlayerCollection:len()
	return #self._list
end

return PlayerCollection
