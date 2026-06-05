--- Multiplayer match representation.

local SlotStatus = require("bancho.constants.SlotStatus")
local MatchConstants = require("bancho.constants.MatchConstants")
local GameMode = require("bancho.constants.GameMode")
local Player = require("bancho.model.Player")
local Mods = require("bancho.constants.Mods")

local class = require("class")

--- Match slot (16 total, indices 0-15).
---@class bancho.model.Slot
---@operator call: bancho.model.Slot
---@field player any? player object or nil
---@field player_id integer?
---@field status integer (SlotStatus.*)
---@field team integer (MatchConstants.MatchTeams.*)
---@field mods integer
---@field loaded boolean
---@field skipped boolean

--- Flat, JSON-serializable slot data.
---@class bancho.model.SlotData
---@field player_id integer?
---@field status integer
---@field team integer
---@field mods integer
---@field loaded boolean
---@field skipped boolean
local Slot = class()

function Slot:new()
	self.player = nil
	self.player_id = nil
	self.status = SlotStatus.OPEN
	self.team = MatchConstants.MatchTeams.NEUTRAL
	self.mods = Mods.NOMOD
	self.loaded = false
	self.skipped = false
	return self
end

--- Check if the slot is empty.
---@return boolean
function Slot:empty()
	return self.player == nil and self.player_id == nil
end

--- Reset slot to open state.
function Slot:reset()
	self.player = nil
	self.player_id = nil
	self.status = SlotStatus.OPEN
	self.team = MatchConstants.MatchTeams.NEUTRAL
	self.mods = Mods.NOMOD
	self.loaded = false
	self.skipped = false
end

--- Copy state from another slot.
---@param other bancho.model.Slot source slot
function Slot:copyFrom(other)
	self.player = other.player
	self.player_id = other.player_id or (other.player and other.player.id) or nil
	self.status = other.status
	self.team = other.team
	self.mods = other.mods
	self.loaded = other.loaded
	self.skipped = other.skipped
end

--- Match with 16 slots, settings, and state.
---@class bancho.model.Match
---@operator call: bancho.model.Match
---@field id integer
---@field name string
---@field passwd string
---@field map_id integer
---@field map_md5 string
---@field map_name string
---@field host_id integer
---@field mode bancho.GameMode
---@field mods integer
---@field freemods boolean
---@field win_condition integer
---@field team_type integer
---@field slots {[integer]: bancho.model.Slot}
---@field in_progress boolean
---@field chat any? channel object

--- Flat, JSON-serializable match data for shared dict storage.
---@class bancho.model.MatchData
---@field id integer
---@field name string
---@field passwd string
---@field map_id integer
---@field map_md5 string
---@field map_name string
---@field host_id integer
---@field mode bancho.GameMode
---@field mods integer
---@field freemods boolean
---@field win_condition integer
---@field team_type integer
---@field in_progress boolean
---@field slots {[integer]: bancho.model.SlotData}
local Match = class()

function Match:new(id, name, passwd, host_id, mode, mods, win_condition, team_type, freemods)
	self.id = id
	self.name = name
	self.passwd = passwd
	self.host_id = host_id
	self.map_id = 0
	self.map_md5 = ""
	self.map_name = ""
	self.mode = mode
	self.mods = mods
	self.freemods = freemods
	self.win_condition = win_condition
	self.team_type = team_type
	self.in_progress = false
	---@type {[integer]: bancho.model.Slot}
	self.slots = {}
	for i = 0, 15 do
		self.slots[i] = Slot()
	end
	return self
end

--- Get slot by player reference.
---@param player bancho.model.Player
---@return bancho.model.Slot?
function Match:getSlot(player)
	for i = 0, 15 do
		local s = self.slots[i]
		if s.player == player then
			return s
		end
		-- Fallback: check player_id (when player ref not resolved due to circular dep)
		if s.player_id ~= nil and s.player_id == player.id then
			return s
		end
	end
	return nil
end

--- Get slot by player ID (works even when player refs aren't resolved).
---@param player_id integer
---@return bancho.model.MatchSlot?
function Match:getSlotById(player_id)
	for i = 0, 15 do
		local s = self.slots[i]
		if s.player and s.player.id == player_id then
			return s
		end
		-- Fallback: check player_id directly (when player ref not resolved)
		if s.player_id ~= nil and s.player_id == player_id then
			return s
		end
	end
	return nil
end

--- Get slot index by player reference.
---@param player bancho.model.Player
---@return integer?
function Match:getSlotId(player)
	for i = 0, 15 do
		local s = self.slots[i]
		if s.player == player then
			return i
		end
		-- Fallback: check player_id (when player ref not resolved due to circular dep)
		if s.player_id ~= nil and s.player_id == player.id then
			return i
		end
	end
	return nil
end

--- Get slot index by player ID (works even when player refs aren't resolved).
---@param player_id integer
---@return integer?
function Match:getSlotIdById(player_id)
	for i = 0, 15 do
		local s = self.slots[i]
		if s.player and s.player.id == player_id then
			return i
		end
		if s.player_id ~= nil and s.player_id == player_id then
			return i
		end
	end
	return nil
end

--- Get first free slot index, or nil.
---@return integer?
function Match:getFree()
	for i = 0, 15 do
		if self.slots[i].status == SlotStatus.OPEN then
			return i
		end
	end
	return nil
end

--- Serialize this match to a flat, JSON-compatible data table.
--- Player references in slots are stored as IDs.
---@return bancho.model.MatchData
function Match:toData()
	---@type bancho.model.MatchData
	local data = {
		id = self.id,
		name = self.name,
		passwd = self.passwd,
		map_id = self.map_id,
		map_md5 = self.map_md5,
		map_name = self.map_name,
		host_id = self.host_id,
		mode = type(self.mode) == "table" and self.mode.value or self.mode,
		mods = self.mods,
		freemods = self.freemods,
		win_condition = self.win_condition,
		team_type = self.team_type,
		in_progress = self.in_progress,
		slots = {},
	}

	for i = 0, 15 do
		local slot = self.slots[i]
		data.slots[i] = {
			player_id = slot.player_id or (slot.player and slot.player.id) or nil,
			status = slot.status,
			team = slot.team,
			mods = slot.mods,
			loaded = slot.loaded,
			skipped = slot.skipped,
		}
	end

	return data
end

--- Reconstruct a Match from flat data.
--- Player references in slots are resolved via the collection.
---
---@param data bancho.model.MatchData
---@param collection? bancho.model.PlayerCollection
---@return bancho.model.Match
function Match:fromData(data, collection)
	local mode = type(data.mode) == "number" and GameMode[data.mode] or data.mode
	local match = Match(
		data.id,
		data.name,
		data.passwd,
		data.host_id,
		mode,
		data.mods,
		data.win_condition,
		data.team_type,
		data.freemods
	)
	match.map_id = data.map_id
	match.map_md5 = data.map_md5
	match.map_name = data.map_name
	match.in_progress = data.in_progress

	-- Restore slots with player references resolved
	-- Always restore player_id so getSlot/getSlotId can use it as fallback
	-- Skip player reference resolution if a Player is currently being deserialized
	-- to avoid circular dependency: Player -> Match -> Player -> Match -> ...
	if data.slots then
		for i = 0, 15 do
			local slotData = data.slots[i]
			if slotData then
				match.slots[i].status = slotData.status
				match.slots[i].team = slotData.team
				match.slots[i].mods = slotData.mods
				match.slots[i].loaded = slotData.loaded
				match.slots[i].skipped = slotData.skipped
				match.slots[i].player_id = slotData.player_id

				if not Player.is_resolving() and collection and slotData.player_id then
					match.slots[i].player = collection:get(nil, slotData.player_id)
				end
			end
		end
	end

	return match
end

--- Broadcast a packet to all players in match slots.
--- Uses player_id fallback when player refs aren't resolved.
---@param packet string
---@param players bancho.model.PlayerCollection
function Match:broadcast(packet, players)
	for i = 0, 15 do
		local slot = self.slots[i]
		local target = slot.player
		if not target and slot.player_id then
			target = players:get(nil, slot.player_id)
		end
		if target then
			target:enqueue(packet)
		end
	end
end

return Match
