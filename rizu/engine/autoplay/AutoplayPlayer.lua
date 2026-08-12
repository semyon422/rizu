local class = require("class")
local VirtualInputEvent = require("rizu.input.VirtualInputEvent")

---@class rizu.AutoplayPlayer
---@operator call: rizu.AutoplayPlayer
local AutoplayPlayer = class()

function AutoplayPlayer:new()
	self:reset()
end

function AutoplayPlayer:reset()
	---@type rizu.LogicNote[]
	self.active_long_notes = {}
end

---@param engine rizu.RhythmEngine
---@param next_time number
function AutoplayPlayer:update(engine, next_time)
	if self.chart ~= engine.chart then
		self.chart = engine.chart
		self.input_map = engine.chart.inputMode:getInputMap()
		self:reset()
	end

	local logic_engine = engine.logic_engine
	local input_map = self.input_map
	local offset = engine.logic_offset
	local target_time = next_time - offset
	local old_time = engine.logic_info.time

	-- Detect seek or rewind
	if target_time < old_time then
		self:reset()
	end

	if target_time == old_time then
		return
	end

	-- 1. Pull new notes into LogicEngine's active_notes
	logic_engine:updateActiveNotes(target_time)

	local active_notes = logic_engine:getActiveNotes()

	-- 2. Sort current active notes by start_time.
	-- This only sorts the ACTIVE list (usually small).
	---@type rizu.LogicNote[]
	local notes_to_check = {}
	for _, note in ipairs(active_notes) do
		-- Only consider notes that haven't been "started" yet by autoplay
		if note.state == "clear" and note:isPlayable() then
			table.insert(notes_to_check, note)
		end
	end

	table.sort(notes_to_check, function(a, b)
		return a.linked_note < b.linked_note
	end)

	-- 3. Process presses
	for _, note in ipairs(notes_to_check) do
		local start_time = note.linked_note:getStartTime()
		if start_time > old_time and start_time <= target_time then
			local col_index = input_map[note:getColumn()]
			engine:setTimeNoAudio(start_time + offset)
			engine:receive(VirtualInputEvent(col_index, true, col_index))

			if note.linked_note:isShort() then
				engine:receive(VirtualInputEvent(col_index, false, col_index))
			else
				table.insert(self.active_long_notes, note)
			end
		end
	end

	-- 4. Process releases for long notes tracked by autoplay
	local i = 1
	while i <= #self.active_long_notes do
		local note = self.active_long_notes[i]
		local end_time = note.linked_note:getEndTime()

		if end_time <= target_time then
			if end_time > old_time then
				local col_index = input_map[note:getColumn()]
				engine:setTimeNoAudio(end_time + offset)
				engine:receive(VirtualInputEvent(col_index, false, col_index))
			end
			table.remove(self.active_long_notes, i)
		else
			i = i + 1
		end
	end

	engine:setTimeNoAudio(next_time)
end

return AutoplayPlayer
