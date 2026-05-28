--- Multiplayer match representation.

local SlotStatus = require("bancho.constants.SlotStatus")
local MatchConstants = require("bancho.constants.MatchConstants")
local GameMode = require("bancho.constants.GameMode")
local Mods = require("bancho.constants.Mods")

local class = require("class")

--- Match slot (16 total, indices 0-15).
---@class bancho.model.Slot
---@operator call: bancho.model.Slot
---@field player any? player object or nil
---@field status integer (SlotStatus.*)
---@field team integer (MatchConstants.MatchTeams.*)
---@field mods integer
---@field loaded boolean
---@field skipped boolean
local Slot = class()

function Slot:new()
	self.player = nil
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
	return self.player == nil
end

--- Reset slot to open state.
function Slot:reset()
	self.player = nil
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
	self.status = other.status
	self.team = other.team
	self.mods = other.mods
	self.loaded = other.loaded
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
	end
	return nil
end

--- Get slot index by player reference.
---@param player bancho.model.Player
---@return integer?
function Match:getSlotId(player)
	for i = 0, 15 do
		if self.slots[i].player == player then
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

return Match
