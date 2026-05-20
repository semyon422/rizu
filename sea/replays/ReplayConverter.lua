local class = require("class")
local int_rates = require("chart.scoring.int_rates")
local ModifierModel = require("sphere.models.ModifierModel")
local ModifierRegistry = require("sphere.models.ModifierModel.ModifierRegistry")
local TimingsDefiner = require("sea.timings.TimingsDefiner")
local Timings = require("sea.chart.Timings")
local Subtimings = require("sea.chart.Subtimings")
local TimingValues = require("sea.chart.TimingValues")
local Healths = require("sea.chart.Healths")
local Replay = require("sea.replays.Replay")
local VirtualInputEvent = require("rizu.input.VirtualInputEvent")

-- LEGACY CODE
-- tests for every replay version are required

---@class sea.ReplayConverter
---@operator call: sea.ReplayConverter
local ReplayConverter = class()

ReplayConverter.oldTimings = {
	ShortNote = {
		hit = {-0.12, 0.12},
		miss = {-0.16, 0.12}
	},
	LongNoteStart = {
		hit = {-0.12, 0.12},
		miss = {-0.16, 0.12},
	},
	LongNoteEnd = {
		hit = {-0.12, 0.12},
		miss = {-0.16, 0.12}
	}
}

---@param replay table
function ReplayConverter:convertTimings(replay)
	local timings = replay.timings
	if not timings then
		replay.timings = self.oldTimings
		return
	end

	if not timings.ShortNote then
		timings.ShortNote = timings.ShortScoreNote
		timings.LongNoteStart = {
			hit = timings.LongScoreNote.startHit,
			miss = timings.LongScoreNote.startMiss,
		}
		timings.LongNoteEnd = {
			hit = timings.LongScoreNote.endHit,
			miss = timings.LongScoreNote.endMiss,
		}
		timings.ShortScoreNote = nil
		timings.LongScoreNote = nil
	end
	if not timings.LongNoteStart then
		timings.LongNoteStart = {
			hit = timings.LongNote.startHit,
			miss = timings.LongNote.startMiss,
		}
		timings.LongNoteEnd = {
			hit = timings.LongNote.endHit,
			miss = timings.LongNote.endMiss,
		}
		timings.LongNote = nil
	end
end

---@param c table
---@param replay table
---@return boolean
function ReplayConverter:convertModifier(c, replay)
	c.version = c.version or 0

	if c.value == nil then
		for k, v in pairs(c) do
			if k ~= "name" and k ~= "version" and k ~= "id" then
				c.value = v
				c[k] = nil
				break
			end
		end
	end

	if c.value == true then
		c.value = nil
	end

	if c.name then
		-- deleted modifiers
		if c.name == "TimeRateQ" then
			replay.rate = replay.rate * 2 ^ (0.1 * c.value)
		elseif c.name == "TimeRateX" then
			replay.rate = replay.rate * c.value
		elseif c.name == "ConstSpeed" then
			replay.const = true
		elseif c.name == "SpeedMode" and c.value == "constant" then
			replay.const = true
		end

		if not replay.timings then
			if c.name == "Automap" then
				c.version = -1
			elseif c.name == "MultiOverPlay" then
				c.value = c.value + 1
			elseif c.name == "MultiplePlay" then
				c.value = c.value + 1
			end
		end

		c.id = ModifierRegistry.enum[c.name]
		if not c.id then
			return false
		end
		c.name = nil

		for k in pairs(c) do
			if k ~= "value" and k ~= "version" and k ~= "id" then
				c[k] = nil
			end
		end

		return true
	end

	if c.value == nil then
		return true
	end
	if c.value == false then
		return false
	end

	return true
end

---@param replay table
function ReplayConverter:convertModifiers(replay)
	local new_modifiers = {}
	for _, c in ipairs(replay.modifiers) do
		if self:convertModifier(c, replay) then
			table.insert(new_modifiers, c)
		end
	end
	replay.modifiers = new_modifiers
	ModifierModel:fixOldFormat(replay.modifiers)
end

---@param events [number, integer, boolean][]
function ReplayConverter:convertEvents(events)
	---@type rizu.ReplayFrame[]
	local frames = {}

	for i, e in ipairs(events) do
		local id, value, column = e[2], e[3], e[2]
		frames[i] = {
			time = e[1],
			event = VirtualInputEvent(id, value, column),
		}
	end

	return frames
end

---@param obj table
---@return sea.Replay
function ReplayConverter:convert(obj)
	if obj.version then
		if obj.version == 1 or obj.version == 2 then
			if obj.timings then
				setmetatable(obj.timings, Timings)
			end
			if obj.subtimings then
				setmetatable(obj.subtimings, Subtimings)
			end
			if obj.healths then
				setmetatable(obj.healths, Healths)
			end
			if obj.timing_values then
				setmetatable(obj.timing_values, TimingValues)
			end
			if obj.events then
				obj.frames = self:convertEvents(obj.events)
				obj.events = nil
			end
			return (setmetatable(obj, Replay))
		end
		error("invalid replay version")
	end

	if obj.events then
		obj.frames = self:convertEvents(obj.events)
		obj.events = nil
	end

	obj.rate = obj.rate or 1
	if not obj.const then
		obj.const = false
	end
	if obj.modifiers then
		self:convertModifiers(obj)
	end
	obj.modifiers = obj.modifiers or {}
	self:convertTimings(obj)

	local replay = Replay()

	replay.version = 0
	replay.frames = obj.frames

	replay.hash = obj.hash
	replay.index = obj.index
	replay.modifiers = obj.modifiers
	replay.rate = int_rates.round(obj.rate)
	replay.mode = obj.single and "taiko" or "mania"

	replay.nearest = not not obj.timings.nearest
	replay.tap_only = false

	local timings, subtimings = TimingsDefiner:match(obj.timings)
	if not timings then
		timings = Timings("arbitrary")
		subtimings = nil
	end
	replay.timings = timings
	replay.subtimings = subtimings
	replay.timing_values = TimingValues():copyFrom(obj.timings)

	-- replay.healths is not defined on this stage
	replay.columns_order = nil

	-- metadata
	replay.custom = false
	replay.const = obj.const
	replay.pause_count = 0
	replay.created_at = obj.time or 0
	replay.rate_type = int_rates.is_q_rate(int_rates.round(obj.rate), 10) and "exp" or "linear"

	return replay
end

return ReplayConverter
