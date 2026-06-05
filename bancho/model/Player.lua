--- Player representation for online players.
---
--- Stores only session data. Persistent data (stats, friends, profile)
--- is stored in the database and accessed via repos.

local Action = require("bancho.constants.Action")
local GameMode = require("bancho.constants.GameMode")
local Privileges = require("bancho.constants.Privileges")
local ClientPrivileges = require("bancho.constants.ClientPrivileges")

local class = require("class")

--- Thread-local flag to prevent circular deserialization.
--- When Player:fromData() is running, Match:fromData() should NOT resolve
--- player references (which would trigger Player:fromData() again).
local registry = debug.getregistry()
local function _isResolvingPlayer()
	return registry._resolving_player == true
end
registry._resolving_player = false

---@class bancho.model.Status
---@field action integer action id (Action.*)
---@field info_text string
---@field map_md5 string
---@field mods integer
---@field mode bancho.GameMode
---@field map_id integer

--- Flat, JSON-serializable player data for shared dict storage.
--- Contains only session data (no stats, no friends).
---@class bancho.model.PlayerData
---@field id integer
---@field name string
---@field safe_name string
---@field priv integer
---@field token string
---@field restricted boolean
---@field silenced boolean
---@field silence_end integer
---@field status bancho.model.Status
---@field blocks integer[]
---@field spectating_id integer?
---@field spectators integer[]
---@field match_id integer?
---@field in_lobby boolean
---@field stealth boolean

---@class bancho.model.Player
---@operator call: bancho.model.Player
---@field id integer
---@field name string
---@field safe_name string
---@field priv integer privileges bitmask
---@field token string
---@field is_online boolean
---@field restricted boolean account restricted status
---@field bancho_priv integer client privileges bitmask
---@field status bancho.model.Status
---@field _packet_queue string[]
---@field silence_end integer
---@field silenced boolean chat silenced status
---@field spectating bancho.model.Player? player being spectated
---@field spectators bancho.model.Player[] players spectating this player
---@field match bancho.model.Match? current multiplayer match
---@field in_lobby boolean whether player is in multiplayer lobby
---@field stealth boolean stealth spectating mode (session-only)
---@field blocks integer[] blocked user IDs (session-only, not persisted)
local Player = class()

--- Generate a unique token.
--- Uses os.time + user ID for uniqueness.
--- Works even with module reloads (lua_code_cache off).
local function _genToken(user_id)
	return string.format('%d-%d-%d', user_id or 0, os.time(), math.random(100000, 999999))
end

function Player:new(id, name, priv)
	self.id = id
	self.name = name
	self.safe_name = name:lower():gsub(" ", "_"):gsub("[^a-z0-9_]", "_")
	self.priv = priv
	self.token = _genToken(id)
	self.is_online = false
	self.restricted = false
	self.silence_end = 0
	self.silenced = false
	self.spectating = nil
	self.spectators = {}
	self.match = nil
	self.in_lobby = false
	self.stealth = false
	self.blocks = {}

	self.status = {
		action = Action.IDLE,
		info_text = "",
		map_md5 = "",
		mods = 0,
		mode = GameMode.fromValue(0),
		map_id = 0,
	}

	---@type string[]
	self._packet_queue = {}
	return self
end

--- Enqueue a packet to be sent to this player.
---@param data string packet data
function Player:enqueue(data)
	table.insert(self._packet_queue, data)
end

--- Dequeue all enqueued packets as a single blob.
---@return string? concatenated packet data or nil if empty
function Player:dequeue()
	if #self._packet_queue == 0 then return nil end
	local data = table.concat(self._packet_queue)
	self._packet_queue = {}
	return data
end

--- Add a spectator watching this player.
---@param spectator bancho.model.Player
function Player:addSpectator(spectator)
	table.insert(self.spectators, spectator)
end

--- Remove a spectator from this player.
---@param spectator bancho.model.Player
function Player:removeSpectator(spectator)
	for i = 1, #self.spectators do
		if self.spectators[i].id == spectator.id then
			table.remove(self.spectators, i)
			break
		end
	end
end

--- Get client-side privileges bitmask.
---@return integer
function Player:bancho_priv()
	local p = ClientPrivileges.PLAYER
	if bit.band(self.priv, Privileges.SUPPORTER) ~= 0 then
		p = bit.bor(p, ClientPrivileges.SUPPORTER)
	end
	if bit.band(self.priv, Privileges.MODERATOR) ~= 0 then
		p = bit.bor(p, ClientPrivileges.MODERATOR)
	end
	if bit.band(self.priv, Privileges.DEVELOPER) ~= 0 then
		p = bit.bor(p, bit.bor(ClientPrivileges.DEVELOPER, ClientPrivileges.OWNER))
	end
	return p
end

--- Serialize this player to a flat, JSON-compatible data table.
--- Cross-references (spectating, spectators, match) are stored as IDs.
--- Contains only session data (no stats, no friends).
---@return bancho.model.PlayerData
function Player:toData()
	---@type bancho.model.PlayerData
	local data = {
		id = self.id,
		name = self.name,
		safe_name = self.safe_name,
		priv = self.priv,
		token = self.token,
		restricted = self.restricted,
		silenced = self.silenced,
		silence_end = self.silence_end,
		status = {
			action = self.status.action,
			info_text = self.status.info_text,
			map_md5 = self.status.map_md5,
			mods = self.status.mods,
			mode = self.status.mode,
			map_id = self.status.map_id,
		},
		blocks = self.blocks,
		spectating_id = self.spectating and self.spectating.id or nil,
		spectators = {}, -- player IDs
		match_id = self.match and self.match.id or nil,
		in_lobby = self.in_lobby,
		stealth = self.stealth,
	}

	for _, spec in ipairs(self.spectators) do
		table.insert(data.spectators, spec.id)
	end

	return data
end

--- Reconstruct a Player from flat data.
--- Cross-references are resolved via the collection.
---
---@param data bancho.model.PlayerData
---@param collection? bancho.model.PlayerCollection
---@return bancho.model.Player
function Player:fromData(data, collection)
	-- Set flag to prevent circular deserialization
	registry._resolving_player = true

	local player = Player(data.id, data.name, data.priv)
	player.token = data.token
	player.safe_name = data.safe_name
	player.restricted = data.restricted
	player.silenced = data.silenced
	player.silence_end = data.silence_end
	player.in_lobby = data.in_lobby or false
	player.stealth = data.stealth or false
	player.blocks = data.blocks or {}

	-- Resolve cross-references
	if collection and data.spectating_id then
		player.spectating = collection:get(nil, data.spectating_id)
	end
	if collection and data.match_id then
		player.match = collection:getMatch(data.match_id)
	end

	-- Spectators are resolved at read time (lazy)
	player.spectators = {} -- IDs stored in data.spectators

	-- Restore status
	if data.status then
		player.status.action = data.status.action
		player.status.info_text = data.status.info_text
		player.status.map_md5 = data.status.map_md5
		player.status.mods = data.status.mods
		player.status.mode = data.status.mode
		player.status.map_id = data.status.map_id
	end

	-- Clear flag
	registry._resolving_player = false
	return player
end

--- Check if a Player is currently being deserialized.
--- Used by Match:fromData() to avoid circular deserialization.
---@return boolean
function Player.is_resolving()
	return registry._resolving_player == true
end

return Player
