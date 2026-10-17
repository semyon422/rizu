--- Chat channel representation.

local Privileges = require("bancho.constants.Privileges")

local class = require("class")

---@class bancho.model.Channel
---@operator call: bancho.model.Channel
---@field name string
---@field real_name string
---@field topic string
---@field players {[integer]: bancho.model.Player} player id -> player
---@field read_priv integer
---@field write_priv integer
---@field auto_join boolean
---@field instance boolean (auto-delete when empty)

--- Flat, JSON-serializable channel data for shared dict storage.
---@class bancho.model.ChannelData
---@field name string
---@field real_name string
---@field topic string
---@field player_ids integer[]
---@field read_priv integer
---@field write_priv integer
---@field auto_join boolean
---@field instance boolean
local Channel = class()

function Channel:new(name, topic, read_priv, write_priv, auto_join, instance)
	self.real_name = name
	if name:sub(1, 6) == "#spec_" then
		self.name = "#spectator"
	elseif name:sub(1, 7) == "#multi_" then
		self.name = "#multiplayer"
	else
		self.name = name
	end
	self.topic = topic
	self.players = {}
	self.read_priv = read_priv or Privileges.UNRESTRICTED
	self.write_priv = write_priv or Privileges.UNRESTRICTED
	self.auto_join = auto_join ~= false
	self.instance = instance or false
	return self
end

--- Check if a player is in the channel.
---@param player bancho.model.Player|string player object or string key
---@return boolean
function Channel:contains(player)
	if type(player) == "string" then
		return self.players[player] ~= nil
	else
		return self.players[player.id] ~= nil
	end
end

--- Check if a player can read the channel.
---@param priv integer privileges bitmask
---@return boolean
function Channel:canRead(priv)
	if self.read_priv == 0 then return true end
	return bit.band(priv, self.read_priv) ~= 0
end

--- Check if a player can write to the channel.
---@param priv integer privileges bitmask
---@return boolean
function Channel:canWrite(priv)
	if self.write_priv == 0 then return true end
	return bit.band(priv, self.write_priv) ~= 0
end

--- Add a player to the channel.
---@param player bancho.model.Player
function Channel:add(player)
	self.players[player.id] = player
end

--- Remove a player from the channel.
---@param player bancho.model.Player
function Channel:remove(player)
	self.players[player.id] = nil
end

--- Serialize this channel to a flat, JSON-compatible data table.
--- Player references are stored as IDs.
---@return bancho.model.ChannelData
function Channel:toData()
	---@type integer[]
	local player_ids = {}
	for id in pairs(self.players) do
		table.insert(player_ids, id)
	end

	---@type bancho.model.ChannelData
	return {
		name = self.name,
		real_name = self.real_name,
		topic = self.topic,
		player_ids = player_ids,
		read_priv = self.read_priv,
		write_priv = self.write_priv,
		auto_join = self.auto_join,
		instance = self.instance,
	}
end

--- Reconstruct a Channel from flat data.
--- Player references are resolved via the collection.
---
---@param data bancho.model.ChannelData
---@param collection? bancho.model.PlayerCollection
---@return bancho.model.Channel
function Channel:fromData(data, collection)
	local channel = Channel(
		data.name,
		data.topic,
		data.read_priv,
		data.write_priv,
		data.auto_join,
		data.instance
	)
	channel.real_name = data.real_name

	-- Resolve player references
	if collection and data.player_ids then
		for _, id in ipairs(data.player_ids) do
			local player = collection:get(nil, id)
			if player then
				channel.players[id] = player
			end
		end
	end

	return channel
end

return Channel
