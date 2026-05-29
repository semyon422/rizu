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

--- Flat, JSON-serializable player data for shared dict storage.
---@class bancho.model.PlayerData
---@field id integer
---@field name string
---@field safe_name string
---@field priv integer
---@field token string
---@field restricted boolean
---@field silenced boolean
---@field silence_end integer
---@field utc_offset integer
---@field pm_private boolean
---@field stealth boolean
---@field in_lobby boolean
---@field away_msg string?
---@field pres_filter integer
---@field spectating_id integer?
---@field spectators integer[]
---@field match_id integer?
---@field blocks integer[]
---@field friends integer[]
---@field status bancho.model.Status
---@field stats {[integer]: bancho.model.ModeStats}

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
---@field in_lobby boolean whether player is in multiplayer lobby
---@field pm_private boolean block non-friend DMs
---@field away_msg string? away message text
---@field pres_filter integer presence filter (0-2)
---@field stealth boolean stealth spectating mode
---@field blocks integer[] blocked user IDs
---@field friends integer[] friend user IDs
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
	self.in_lobby = false
	self.pm_private = false
	self.away_msg = nil
	self.pres_filter = 0
	self.stealth = false
	self.blocks = {}
	self.friends = {}

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

--- Serialize this player to a flat, JSON-compatible data table.
--- Cross-references (spectating, spectators, match) are stored as IDs.
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
		utc_offset = self.utc_offset,
		pm_private = self.pm_private,
		stealth = self.stealth,
		in_lobby = self.in_lobby,
		away_msg = self.away_msg,
		pres_filter = self.pres_filter,
		spectating_id = self.spectating and self.spectating.id or nil,
		spectators = {}, -- player IDs
		match_id = self.match and self.match.id or nil,
		blocks = self.blocks,
		friends = self.friends,
		status = {
			action = self.status.action,
			info_text = self.status.info_text,
			map_md5 = self.status.map_md5,
			mods = self.status.mods,
			mode = self.status.mode,
			map_id = self.status.map_id,
		},
		stats = {},
	}

	for _, spec in ipairs(self.spectators) do
		table.insert(data.spectators, spec.id)
	end

	for mode, mode_stats in pairs(self.stats) do
		local mode_val = type(mode) == "table" and mode.value or mode
		data.stats[mode_val] = {
			tscore = mode_stats.tscore,
			rscore = mode_stats.rscore,
			pp = mode_stats.pp,
			acc = mode_stats.acc,
			plays = mode_stats.plays,
			playtime = mode_stats.playtime,
			max_combo = mode_stats.max_combo,
			rank = mode_stats.rank,
			grades = {},
		}
		for grade, count in pairs(mode_stats.grades) do
			local grade_val = type(grade) == "table" and grade.value or grade
			data.stats[mode_val].grades[grade_val] = count
		end
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
	local player = Player(data.id, data.name, data.priv)
	player.token = data.token
	player.safe_name = data.safe_name
	player.restricted = data.restricted
	player.silenced = data.silenced
	player.silence_end = data.silence_end
	player.utc_offset = data.utc_offset
	player.pm_private = data.pm_private
	player.stealth = data.stealth
	player.in_lobby = data.in_lobby
	player.away_msg = data.away_msg
	player.pres_filter = data.pres_filter
	player.blocks = data.blocks or {}
	player.friends = data.friends or {}

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

	-- Restore stats
	if data.stats then
		for mode_key, mode_stats in pairs(data.stats) do
			local mode = type(mode_key) == "number" and GameMode[mode_key] or mode_key
			player.stats[mode].tscore = mode_stats.tscore
			player.stats[mode].rscore = mode_stats.rscore
			player.stats[mode].pp = mode_stats.pp
			player.stats[mode].acc = mode_stats.acc
			player.stats[mode].plays = mode_stats.plays
			player.stats[mode].playtime = mode_stats.playtime
			player.stats[mode].max_combo = mode_stats.max_combo
			player.stats[mode].rank = mode_stats.rank
			if mode_stats.grades then
				for grade_key, count in pairs(mode_stats.grades) do
					local grade
					if type(grade_key) == "number" then
						-- Find Grade object by value
						for _, g in ipairs({Grade.N, Grade.F, Grade.D, Grade.C, Grade.B, Grade.A, Grade.S, Grade.SH, Grade.X, Grade.XH}) do
							if g.value == grade_key then
								grade = g
								break
							end
						end
					else
						grade = grade_key
					end
					if grade then
						player.stats[mode].grades[grade] = count
					end
				end
			end
		end
	end

	return player
end

return Player
