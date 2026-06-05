--- Multiplayer match lifecycle manager.
---
--- Handles creating, joining, leaving, readying, starting, and completing matches.
--- State changes are tracked; packet serialization is the caller's responsibility.

local bit = require("bit")
local Match = require("bancho.model.Match")
local SlotStatus = require("bancho.constants.SlotStatus")
local ServerPackets = require("bancho.protocol.ServerPackets")

local class = require("class")

--- Match manager: coordinates multiplayer match lifecycle.
---@class bancho.multiplayer.MatchManager
---@operator call: bancho.multiplayer.MatchManager
---@field matches bancho.model.MatchCollection
local MatchManager = class()

function MatchManager:new(matches)
	self.matches = matches or require("bancho.model.MatchCollection")()
	return self
end

--- Create a new match.
--- Uses atomic :add() to prevent race conditions on multi-worker servers.
---@param name string
---@param password string
---@param host_id integer
---@param mode integer
---@param mods integer
---@param win_condition integer
---@param team_type integer
---@param freemods boolean
---@return bancho.model.Match?
function MatchManager:create(name, password, host_id, mode, mods, win_condition, team_type, freemods)
	local id = self.matches:getFree()
	if id == nil then return nil end

	local m = Match(id, name, password, host_id, mode, mods, win_condition, team_type, freemods)
	if not self.matches:add(m) then
		-- Another worker claimed this slot — retry with next free slot
		id = self.matches:getFree()
		if id == nil then return nil end

		m = Match(id, name, password, host_id, mode, mods, win_condition, team_type, freemods)
		if not self.matches:add(m) then
			return nil  -- give up after one retry
		end
	end

	return m
end

--- Add a player to a match.
---@param match bancho.model.Match
---@param player bancho.model.Player
---@return boolean true on success
function MatchManager:addPlayer(match, player)
	local slot_id = match:getFree()
	if slot_id == nil then return false end

	local slot = match.slots[slot_id]
	slot.player = player
	slot.player_id = player.id
	slot.status = SlotStatus.NOT_READY

	-- Add player to match chat channel and announce membership.
	if match.chat then
		match.chat:add(player)
		player:enqueue(ServerPackets.channelJoin(match.chat.name))

		local count = 0
		for _ in pairs(match.chat.players) do
			count = count + 1
		end
		local info = ServerPackets.channelInfo(match.chat.name, match.chat.topic, count)
		for _, p in pairs(match.chat.players) do
			p:enqueue(info)
		end
	end

	return true
end

--- Remove a player from a match.
---@param match bancho.model.Match
---@param player bancho.model.Player
function MatchManager:removePlayer(match, player)
	local slot_id = match:getSlotId(player)
	if slot_id == nil then return end

	local slot = match.slots[slot_id]
	slot:reset()

	-- Remove player from match chat channel and announce departure.
	if match.chat and match.chat:contains(player) then
		match.chat:remove(player)
		player:enqueue(ServerPackets.channelKick(match.chat.name))

		local count = 0
		for _ in pairs(match.chat.players) do
			count = count + 1
		end
		local info = ServerPackets.channelInfo(match.chat.name, match.chat.topic, count)
		for _, p in pairs(match.chat.players) do
			p:enqueue(info)
		end
	end
end

--- Set a player's ready status.
---@param match bancho.model.Match
---@param player bancho.model.Player
---@param ready boolean
function MatchManager:setReady(match, player, ready)
	local slot = match:getSlot(player)
	if not slot then return end

	if ready then
		slot.status = SlotStatus.READY
	else
		slot.status = SlotStatus.NOT_READY
	end
end

--- Set a player's mods.
---@param match bancho.model.Match
---@param player bancho.model.Player
---@param mods integer
function MatchManager:setMods(match, player, mods)
	local slot = match:getSlot(player)
	if not slot then return end

	slot.mods = mods
end

--- Set a player's team.
---@param match bancho.model.Match
---@param player bancho.model.Player
---@param team integer
function MatchManager:setTeam(match, player, team)
	local slot = match:getSlot(player)
	if not slot then return end

	slot.team = team
end

--- Mark a player as loaded.
---@param match bancho.model.Match
---@param player bancho.model.Player
function MatchManager:setLoaded(match, player)
	local slot = match:getSlot(player)
	if not slot then return end

	slot.loaded = true
end

--- Start the match.
---@param match bancho.model.Match
function MatchManager:start(match)
	match.in_progress = true
end

--- Complete a player's play in the match.
---@param match bancho.model.Match
---@param player bancho.model.Player
---@param score bancho.model.Score
function MatchManager:complete(match, player, score)
	local slot = match:getSlot(player)
	if not slot then return end

	slot.status = SlotStatus.COMPLETED
end

--- Handle a player failing the match.
---@param match bancho.model.Match
---@param player bancho.model.Player
function MatchManager:fail(match, player)
	local slot = match:getSlot(player)
	if not slot then return end

	slot.status = SlotStatus.FAILED
end

--- Transfer host to a new player.
---@param match bancho.model.Match
---@param new_host bancho.model.Player
function MatchManager:transferHost(match, new_host)
	if not match:getSlot(new_host) then return end
	match.host_id = new_host.id
end

--- Change match password.
---@param match bancho.model.Match
---@param new_password string
function MatchManager:changePassword(match, new_password)
	match.passwd = new_password
end

--- Get all players in a match.
---@param match bancho.model.Match
---@return bancho.model.Player[]
function MatchManager:getPlayers(match)
	---@type bancho.model.Player[]
	local players = {}
	for i = 0, 15 do
		if match.slots[i].player ~= nil then
			table.insert(players, match.slots[i].player)
		end
	end
	return players
end

--- Get all players with a given slot status.
---@param match bancho.model.Match
---@param status integer
---@return bancho.model.Player[]
function MatchManager:getPlayersByStatus(match, status)
	---@type bancho.model.Player[]
	local players = {}
	for i = 0, 15 do
		if match.slots[i].player ~= nil and match.slots[i].status == status then
			table.insert(players, match.slots[i].player)
		end
	end
	return players
end

--- Check if all players are ready.
---@param match bancho.model.Match
---@return boolean
function MatchManager:allReady(match)
	for i = 0, 15 do
		if match.slots[i].player ~= nil and match.slots[i].status ~= SlotStatus.READY then
			return false
		end
	end
	return true
end

--- Check if all players are loaded.
---@param match bancho.model.Match
---@return boolean
function MatchManager:allLoaded(match)
	for i = 0, 15 do
		if match.slots[i].player ~= nil and not match.slots[i].loaded then
			return false
		end
	end
	return true
end

--- Build a protocol-friendly match data table for packet serialization.
---@param match bancho.model.Match
---@return bancho.protocol.MultiplayerMatch
function MatchManager:buildMatchData(match)
	---@type integer[]
	local slot_statuses = {}
	---@type integer[]
	local slot_teams = {}
	---@type integer[]
	local slot_ids = {}
	---@type integer[]
	local slot_mods = {}

	for i = 0, 15 do
		slot_statuses[#slot_statuses + 1] = match.slots[i].status
		slot_teams[#slot_teams + 1] = match.slots[i].team
		if bit.band(match.slots[i].status, 124) ~= 0 then
			if match.slots[i].player ~= nil then
				slot_ids[#slot_ids + 1] = match.slots[i].player.id
			elseif match.slots[i].player_id ~= nil then
				slot_ids[#slot_ids + 1] = match.slots[i].player_id
			end
		end
		slot_mods[#slot_mods + 1] = match.slots[i].mods
	end

	return {
		id = match.id,
		in_progress = match.in_progress,
		powerplay = 0,
		mods = match.mods,
		name = match.name,
		passwd = match.passwd,
		map_name = match.map_name,
		map_id = match.map_id,
		map_md5 = match.map_md5,
		slot_statuses = slot_statuses,
		slot_teams = slot_teams,
		slot_ids = slot_ids,
		slot_mods = slot_mods,
		host_id = match.host_id,
		mode = type(match.mode) == "table" and match.mode.value or match.mode,
		win_condition = match.win_condition,
		team_type = match.team_type,
		freemods = match.freemods,
		seed = 0,
	}
end

--- Dispose a match.
---@param match_id integer
function MatchManager:dispose(match_id)
	local match = self.matches:get(match_id)
	if not match then return end
	self.matches:remove(match)
end

return MatchManager
