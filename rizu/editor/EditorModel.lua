local class = require("class")
local AudioManager = require("rizu.editor.AudioManager")
local TimeManager = require("rizu.editor.TimeManager")
local GraphicEngine = require("rizu.editor.GraphicEngine")
local just = require("just")
local Changes = require("Changes")
local NoteChartLoader = require("rizu.editor.NoteChartLoader")
local MainAudio = require("rizu.editor.MainAudio")
local NcbtContext = require("rizu.editor.NcbtContext")
local IntervalManager = require("rizu.editor.IntervalManager")
local GraphsGenerator = require("rizu.editor.GraphsGenerator")
local EditorChanges = require("rizu.editor.EditorChanges")
local NoteManager = require("rizu.editor.NoteManager")
local Scroller = require("rizu.editor.Scroller")
local Metronome = require("rizu.editor.Metronome")
local pattern_analyzer = require("libchart.pattern_analyzer")
local Point = require("chartedit.Point")
local Metadata = require("sph.Metadata")

---@class rizu.editor.EditorModel
---@operator call: rizu.editor.EditorModel
---@field layer chartedit.Layer
local EditorModel = class()

EditorModel.tools = {"Select", "ShortNote", "LongNote", "SoundNote"}
EditorModel.states = {"info", "audio", "timings", "notes", "bms"}
EditorModel.max_snap = 192

---@param configModel sphere.ConfigModel
---@param resourceModel sphere.ResourceModel
function EditorModel:new(configModel, resourceModel)
	self.configModel = configModel
	self.resourceModel = resourceModel

	self.noteChartLoader = NoteChartLoader()
	self.mainAudio = MainAudio()
	self.ncbtContext = NcbtContext()
	self.intervalManager = IntervalManager()
	self.graphsGenerator = GraphsGenerator()
	self.editorChanges = EditorChanges()
	self.timer = TimeManager()
	self.timer:setGlobalTime(0)
	self.audioManager = AudioManager(self.timer, resourceModel)
	self.noteManager = NoteManager()
	self.graphicEngine = GraphicEngine()
	self.scroller = Scroller()
	self.metronome = Metronome()
	self.metadata = Metadata()

	for _, v in pairs(self) do
		v.editorModel = self
	end
	self.state = self.states[1]

	self.bms_tools = {}
end

function EditorModel:load()
	self.loaded = true

	local editor = self:getSettings()

	self.layer, self.notes = self.noteChartLoader:load()
	self.visual = self.layer.visuals.main or self.layer.visuals[""]

	self.patterns_analyzed = pattern_analyzer.format(pattern_analyzer.analyze(self.chart))

	self.changes = Changes()
	-- ld:syncChanges(self.changes:get())

	self.graphsGenerator:load()

	self.resourcesLoaded = false

	self.point = Point()
	self:getDtpAbsolute(0):clone(self.point)

	self.timer:pause()
	self.timer:setGlobalTime(editor.time)
	self.timer:setTime(editor.time)

	local volume = self.configModel.configs.settings.audio.volume
	self.audioManager.volume = volume
	self.audioManager.format = self.chartmeta.format
	self.audioManager:load()

	self.mainAudio.volume = volume
	self.mainAudio:load()

	self.metronome.volume = volume
	self.metronome:load()

	self.scroller:scrollSeconds(self.timer:getTime())

	self.bms_tools = {
		offset = self.layer.points:getFirstPoint().interval.offset,
		tempo = self.layer.points:getFirstPoint().interval:getTempo(),
		beat_offset = 0,
	}

	self.metadata:new()
	self.metadata:fromChartmeta(self.chartmeta)
end

function EditorModel:detectTempoOffset()
	if self.mainAudio.soundData then
		self.ncbtContext:detect(self.mainAudio.soundData)
	end
end

function EditorModel:applyNcbt()
	self.ncbtContext:apply(self.layer)
end

function EditorModel:resetOffsetTempo()
	local offset = self.bms_tools.offset
	local tempo = self.bms_tools.tempo

	local layer = self.layer

	local p1 = layer.points:getFirstPoint()
	local p2 = layer.points:getLastPoint()

	if not p1 or not p2 then
		return
	end

	p1.interval.offset = offset
	p2.interval.offset = offset + p2:sub(p1):tonumber() * 60 / tempo
end

---@return table
function EditorModel:getSettings()
	local editor = self.configModel.configs.settings.editor
	if editor.speed <= 0 then
		editor.speed = 1
	end
	editor.snap = math.min(math.max(editor.snap, 1), self.max_snap)
	return editor
end

---@return table
function EditorModel:getAudioSettings()
	return self.configModel.configs.settings.audio
end

function EditorModel:undo()
	self.editorChanges:undo()
end

function EditorModel:redo()
	self.editorChanges:redo()
end

---@param time number
function EditorModel:setTime(time)
	self.timer:setTime(time)
	self.audioManager:update(true)
	self.mainAudio:update(true)
end

---@return number
---@return number
function EditorModel:getIterRange()
	local editor = self:getSettings()
	local absoluteTime = self.point.absoluteTime
	local delta = 1 / editor.speed
	return absoluteTime - delta, absoluteTime + delta
end

function EditorModel:loadResources()
	if not self.loaded then
		return
	end

	local chart = self.chart

	self.mainAudio:loadResources(chart)
	self.audioManager:loadResources(chart, self:getAudioSettings())

	self.audioManager:update(true)
	self.mainAudio:update(true)

	self:genGraphs()

	self.resourcesLoaded = true
end

---@return number
---@return number
function EditorModel:getFirstLastTime()
	local audioManager = self.audioManager
	local mainAudio = self.mainAudio
	local layer = self.layer

	local firstTime = math.min(
		audioManager.firstTime,
		mainAudio.offset,
		layer.points:getFirstPoint():tonumber()
	)
	local lastTime = math.max(
		audioManager.lastTime,
		mainAudio.offset + mainAudio.duration,
		layer.points:getLastPoint():tonumber()
	)
	return firstTime, lastTime
end

function EditorModel:genGraphs()
	local a, b = self:getFirstLastTime()
	self.graphsGenerator:genDensityGraph(self.chart, a, b)
	self.graphsGenerator:genIntervalsGraph(self.layer, a, b)
end

---@param time number
---@return chartedit.Point?
function EditorModel:getDtpAbsolute(time)
	local editor = self:getSettings()
	local p = self.layer.points:interpolateAbsolute(editor.snap, time)
	p.absoluteTime = time
	return p
end

function EditorModel:unload()
	self.loaded = false
	self.audioManager:unload()
	self.mainAudio:unload()
	self.metronome:unload()
end

function EditorModel:save()
	self.chartmeta = self.metadata:toChartmeta()
	self.noteChartLoader:save()
end

function EditorModel:play()
	if self.intervalManager:isGrabbed() then
		return
	end
	self.timer:play()
	self.audioManager:play()
	self.mainAudio:play()
end

function EditorModel:pause()
	self.timer:pause()
	self.audioManager:pause()
	self.mainAudio:pause()
end

---@return number
function EditorModel:getLogSpeed()
	local editor = self:getSettings()
	return math.floor(10 * math.log(editor.speed, 2) + 0.5)
end

---@param logSpeed number
function EditorModel:setLogSpeed(logSpeed)
	local editor = self:getSettings()
	editor.speed = 2 ^ (logSpeed / 10)
end

---@param dy number?
---@return number
function EditorModel:getMouseTime(dy)
	dy = dy or 0
	local mx, my = love.graphics.inverseTransformPoint(love.mouse.getPosition())
	local noteSkin = self.noteSkin
	local editor = self:getSettings()
	return self.point.absoluteTime - noteSkin:getInverseTimePosition(my + dy) / editor.speed
end

---@param note rizu.editor.EditorNote
function EditorModel:selectNote(note)
	self.graphicEngine:selectNote(note, love.keyboard.isDown("lctrl"))
end

function EditorModel:selectStart()
	self.graphicEngine:selectStart()
	local mx, my = love.graphics.inverseTransformPoint(love.mouse.getPosition())
	self.selectRect = {mx, my, mx, my}
	self.selectStartTime = self:getMouseTime()
	just.select(mx, my, mx, my)
end

function EditorModel:selectEnd()
	self.graphicEngine:selectEnd()
	self.selectRect = nil
	just.unselect()
end

function EditorModel:update()
	local editor = self:getSettings()
	local noteSkin = self.noteSkin

	local time = self.timer:getTime()
	editor.time = time

	self.noteManager:update()
	self.metronome:update()

	if self.selectRect then
		local mx, my = love.graphics.inverseTransformPoint(love.mouse.getPosition())
		self.selectRect[2] = noteSkin:getTimePosition((time - self.selectStartTime) * editor.speed)
		self.selectRect[3] = mx
		self.selectRect[4] = my
		just.select(self.selectRect[1], self.selectRect[2], mx, my)
	end

	local dtp = self:getDtpAbsolute(time)
	if self.intervalManager.grabbedInterval then
		self.intervalManager:moveGrabbed(time)
	end
	self.audioManager:update()
	self.mainAudio:update()

	dtp:clone(self.point)

	self.graphicEngine:update()
end

---@param event table
function EditorModel:receive(event)
	if event.name == "framestarted" then
		local timer = self.timer
		timer:setGlobalTime(event.time)
	end
end

function EditorModel:incSnap()
	local editor = self:getSettings()
	editor.snap = editor.snap * 2
	editor.snap = math.min(math.max(editor.snap, 1), self.max_snap)
end

function EditorModel:decSnap()
	local editor = self:getSettings()
	editor.snap = math.floor(editor.snap / 2)
	editor.snap = math.min(math.max(editor.snap, 1), self.max_snap)
end

---@param j number|table
---@return number
function EditorModel:getSnap(j)
	local editor = self:getSettings()
	local snap = editor.snap
	if type(j) == "table" then
		j, snap = 16 * j, 16
	end
	local k
	for i = 1, 16 do
		if snap % i == 0 and j % (snap / i) == 0 then
			k = i
			break
		end
	end
	return k
end

---@return number
---@return number
function EditorModel:getTotalBeats()
	local layer = self.layer
	local a = layer.points:getFirstPoint()
	local b = layer.points:getLastPoint()

	local beats = b:sub(a)
	local avgBeatDuration = (b.absoluteTime - a.absoluteTime) / beats

	return beats, avgBeatDuration
end

return EditorModel
