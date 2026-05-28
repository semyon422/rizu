--- Player representation for online players.

local Action = require("bancho.constants.Action")
local GameMode = require("bancho.constants.GameMode")
local Grade = require("bancho.constants.Grade")
local Privileges = require("bancho.constants.Privileges")
local ClientPrivileges = require("bancho.constants.ClientPrivileges")

local class = require("class")

---@class bancho.model.ModeStats
---@field tscore integer total score
---@field rscore integer ranked score
---@field pp integer
---@field acc number accuracy (0-100)
---@field plays integer
---@field playtime integer
---@field max_combo integer
---@field rank integer global rank
---@field grades {[bancho.Grade]: integer} grade counts

---@class bancho.model.Status
---@field action integer action id (Action.*)
---@field info_text string
---@field map_md5 string
---@field mods integer
---@field mode bancho.GameMode
---@field map_id integer

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
---@field stats {[integer]: bancho.model.ModeStats} stats by game mode
---@field _packet_queue string[]
---@field silence_end integer
---@field silenced boolean chat silenced status
---@field utc_offset integer
---@field spectating bancho.model.Player? player being spectated
---@field spectators bancho.model.Player[] players spectating this player
---@field match bancho.model.Match? current multiplayer match
local Player = class()

--- Generate a random UUID token (simplified).
local _token_counter = 0
local function _genToken()
	_token_counter = _token_counter + 1
	return tostring(_token_counter) .. "-" .. tostring(os.time()) .. "-" .. tostring(math.random(100000, 999999))
end

function Player:new(id, name, priv)
	self.id = id
	self.name = name
	self.safe_name = name:lower():gsub(" ", "_"):gsub("[^a-z0-9_]", "_")
	self.priv = priv
	self.token = _genToken()
	self.is_online = false
	self.restricted = false
	self.silence_end = 0
	self.silenced = false
	self.utc_offset = 0
	self.spectating = nil
	self.spectators = {}
	self.match = nil

	self.status = {
		action = Action.IDLE,
		info_text = "",
		map_md5 = "",
		mods = 0,
		mode = GameMode.fromValue(0),
		map_id = 0,
	}

	--- Initialize default stats for all game modes.
	---@type {[integer]: bancho.model.ModeStats}
	self.stats = {}
	for i = 0, 11 do
		self.stats[i] = {
			tscore = 0,
			rscore = 0,
			pp = 0,
			acc = 0.0,
			plays = 0,
			playtime = 0,
			max_combo = 0,
			rank = 0,
			grades = {
				[Grade.XH] = 0,
				[Grade.X] = 0,
				[Grade.SH] = 0,
				[Grade.S] = 0,
				[Grade.A] = 0,
			},
		}
	end

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

return Player
