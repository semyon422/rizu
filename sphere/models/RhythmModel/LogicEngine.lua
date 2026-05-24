local class = require("class")
local NoteHandler = require("sphere.models.RhythmModel.LogicEngine.NoteHandler")
local Observable = require("Observable")

---@class sphere.LogicEngine
---@operator call: sphere.LogicEngine
local LogicEngine = class()

LogicEngine.inputOffset = 0
LogicEngine.singleHandler = false
LogicEngine.check1024 = true

---@param timeEngine sphere.TimeEngine
---@param scoreEngine sphere.ScoreEngine
function LogicEngine:new(timeEngine, scoreEngine)
	self.observable = Observable()
	self.timeEngine = timeEngine
	self.scoreEngine = scoreEngine
end

---@param chart chart.Chart
function LogicEngine:setChart(chart)
	self.chart = chart
end

function LogicEngine:load()
	---@type {[chart.Note]: sphere.LogicalNote}
	self.sharedLogicalNotes = {}

	---@type sphere.NoteHandler[]
	self.noteHandlers = {}

	if not self.singleHandler then
		for column, notes in pairs(self.chart.notes:getColumnLinkedNotes()) do
			local noteHandler = NoteHandler(self, notes)
			self.noteHandlers[column] = noteHandler
		end
	else
		local noteHandler = NoteHandler(self, self.chart.notes:getLinkedNotes())
		self.noteHandlers[1] = noteHandler
	end

	local notesCount = 0
	for _, noteHandler in pairs(self.noteHandlers) do
		noteHandler:load()
		for _, note in ipairs(noteHandler.notes) do
			if note.isScorable then
				notesCount = notesCount + 1
			end
		end
	end
	self.notesCount = notesCount
end

function LogicEngine:unload()
	self.autoplay = false
	self.promode = false
end

function LogicEngine:update()
	for _, noteHandler in pairs(self.noteHandlers) do
		noteHandler:update()
	end
end

---@param event table
function LogicEngine:receive(event)
	if not event.virtual or self.autoplay then
		return
	end

	local input = event[1]

	local noteHandler
	if not self.singleHandler then
		noteHandler = self.noteHandlers[input]
	else
		noteHandler = self.noteHandlers[1]
	end

	if not noteHandler then
		return
	end

	self.eventTime = event.time

	if self.check1024 then
		-- local ct = self.timeEngine.currentTime
		-- if ct ~= math.huge and self.eventTime < ct then
		-- 	error(("%s < %s"):format(self.eventTime, self.timeEngine.currentTime))
		-- end
		-- assert((self:getEventTime() * 1024) % 1 == 0)
	end
	self:update()
	noteHandler:setKeyState(event.name == "keypressed", input)

	self.eventTime = nil
end

---@param note chart.Note
---@return sphere.LogicalNote?
function LogicEngine:getLogicalNote(note)
	return self.sharedLogicalNotes[note]
end

---@param event table
function LogicEngine:sendScore(event)
	self.scoreEngine:receive(event)
end

---@param note chart.Note
---@param isBackground boolean?
function LogicEngine:playSound(note, isBackground)
	self.observable:send({
		name = "LogicalNoteSound",
		note, isBackground
	})
end

---@return number
function LogicEngine:getEventTime()
	return self.eventTime or self.timeEngine.currentTime
end

---@return number
function LogicEngine:getTimeRate()
	return self.timeRate or self.timeEngine.timeRate
end

---@return number
function LogicEngine:getInputOffset()
	return self.inputOffset
end

return LogicEngine
