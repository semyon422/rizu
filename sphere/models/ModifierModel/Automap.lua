local math_util = require("math_util")
local Upscaler = require("chart.transform.Upscaler")
local NextUpscaler = require("chart.transform.NextUpscaler")
local Reductor = require("chart.transform.Reductor")
local BlockFinder = require("chart.transform.BlockFinder")
local NotePreprocessor = require("chart.transform.NotePreprocessor")
local Modifier = require("sphere.models.ModifierModel.Modifier")
local AutomapOldConfig = require("sphere.models.ModifierModel.AutomapOldConfig")
local InputMode = require("chart.core.InputMode")
local AbsoluteLayer = require("chart.model.layers.AbsoluteLayer")
local Notes = require("chart.model.notes.Notes")
local Note = require("chart.model.notes.Note")

---@class sphere.Automap: sphere.Modifier
---@operator call: sphere.Automap
local Automap = Modifier + {}

Automap.name = "Automap"

Automap.defaultValue = 10
Automap.values = {}

for i = 1, 26 do
	table.insert(Automap.values, i)
end

Automap.description = "anyK to anyK conversion"

---@param config table
---@return string
---@return string
function Automap:getString(config)
	return "AM", tostring(config.value)
end

---@param config table
---@param state table
function Automap:applyMeta(config, state)
	local columnCount = state.inputMode.key
	if not columnCount or config.value == columnCount then
		return
	end

	state.inputMode.key = config.value
end

---@param config table
---@param chart chart.Chart
function Automap:apply(config, chart)
	self.old = config.version == -1
	self.targetMode = config.value

	self.chart = chart
	self.columnCount = chart.inputMode.key

	if self.targetMode == self.columnCount or self.columnCount == 0 then
		return
	end

	self:applyAutomap()
	if self.targetMode < self.columnCount then
		self:processReductor()
	elseif self.targetMode > self.columnCount then
		self:processUpscaler()
	end

	chart:compute()
end

function Automap:applyAutomap()
	local chart = self.chart

	local tNoteDatas = {}
	self.tNoteDatas = tNoteDatas

	local new_notes = Notes()
	for _, lnote in ipairs(chart.notes:getLinkedNotes()) do
		local inputType, inputIndex = InputMode:splitInput(lnote:getColumn())
		if inputType == "key" then
			local n = {}

			n.noteData = lnote
			n.startTime = math_util.round(lnote:getStartTime() * 1000)
			n.endTime = math_util.round(lnote:getEndTime() * 1000)
			n.long = lnote:isLong()
			n.baseEndTime = n.endTime
			n.columnIndex = inputIndex
			n.baseColumnIndex = inputIndex

			tNoteDatas[#tNoteDatas + 1] = n
		else
			new_notes:insert(lnote.startNote)
			if lnote.endNote then
				new_notes:insert(lnote.endNote)
			end
		end
	end
	chart.notes = new_notes

	table.sort(tNoteDatas, function(noteData1, noteData2)
		return noteData1.startTime < noteData2.startTime
	end)
end

function Automap:processUpscaler()
	local chart = self.chart

	local targetMode = self.targetMode
	local columnCount = self.columnCount

	NotePreprocessor.columnCount = columnCount
	NotePreprocessor:process(self.tNoteDatas)

	local bf = BlockFinder()
	bf.noteData = self.tNoteDatas
	bf.columnCount = columnCount
	bf:process()

	self.nbs = bf:getNoteBlocks()

	NotePreprocessor:process(self.nbs)

	local notes
	if self.old then
		notes = self:getOldUpscalerNotes()
	else
		notes = self:getUpscalerNotes()
	end

	for i = 1, #notes do
		local n = notes[i]
		n.noteData:setColumn("key" .. n.columnIndex)
		chart.notes:insertLinked(n.noteData)
	end

	self.chart.inputMode.key = targetMode
end

---@return table
function Automap:getOldUpscalerNotes()
	local am = Upscaler()
	am.columns = AutomapOldConfig[self.targetMode][self.columnCount]
	am:load(self.targetMode)
	local notes, blocks = am:process(self.nbs)

	return notes
end

---@return table
function Automap:getUpscalerNotes()
	local am = NextUpscaler()
	am.targetMode = self.targetMode
	am.columnCount = self.columnCount
	am.notes = self.nbs
	am:process()

	local columns = {}
	local notes = {}
	for _, noteBlock in ipairs(self.nbs) do
		for _, note in ipairs(noteBlock:getNotes()) do
			notes[#notes + 1] = note
			columns[noteBlock.columnIndex] = (columns[noteBlock.columnIndex] or 0) + 1
		end
	end

	return notes
end

function Automap:processReductor()
	local chart = self.chart

	local targetMode = self.targetMode
	local columnCount = self.columnCount

	local tNoteDatasMap = {}
	for _, tNoteData in ipairs(self.tNoteDatas) do
		tNoteData.endTime = tNoteData.startTime
		tNoteDatasMap[tNoteData] = true
	end

	NotePreprocessor.columnCount = columnCount
	NotePreprocessor:process(self.tNoteDatas)

	local reductor = Reductor()
	local notes = reductor:process(self.tNoteDatas, columnCount, targetMode)

	-- currently Automap only absolute time mode
	-- reducting long notes requires creating new time points
	-- time point interpolating is not fully inplemented in LayerData
	-- if not (AbsoluteLayer * self.chart.layers.main) then
	-- 	for _, tNoteData in ipairs(self.tNoteDatas) do
	-- 		tNoteData.endTime = tNoteData.startTime
	-- 	end
	-- end

	local layer = chart.layers.main
	for i = 1, #notes do
		local n = notes[i]
		tNoteDatasMap[n] = nil

		n.noteData:setColumn("key" .. n.columnIndex)

		if n.long then
			if n.startTime == n.endTime then
				n.noteData:unlink()
				n.noteData:setType("tap")
			else
				local p = layer:getPoint(n.endTime / 1000)
				local vp = layer.visuals.main:newPoint(p)
				n.noteData.endNote.visualPoint = vp
			end
		end

		chart.notes:insertLinked(n.noteData)
	end

	for n in pairs(tNoteDatasMap) do
		local note = n.noteData.startNote

		local vp = note.visualPoint
		local snote = chart.notes:get(vp, "auto")
		if not snote then
			snote = Note(vp, "auto", "sample")
			snote.data.sounds = {}
			chart.notes:insert(snote)
		end
		if note.data.sounds then
			for _, s in ipairs(note.data.sounds) do
				table.insert(snote.data.sounds, s)
			end
		end
	end

	self.chart.inputMode.key = targetMode
end

return Automap
