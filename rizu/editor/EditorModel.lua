local class = require("class")
local AudioEngine = require("rizu.engine.audio.Engine")
local TimeManager = require("rizu.editor.TimeManager")
local VisualEngine = require("rizu.editor.VisualEngine")
local just = require("just")
local Changes = require("Changes")
local NoteChartLoader = require("rizu.editor.NoteChartLoader")
local NcbtContext = require("rizu.editor.NcbtContext")
local IntervalManager = require("rizu.editor.IntervalManager")
local GraphsGenerator = require("rizu.editor.GraphsGenerator")
local EditorChanges = require("rizu.editor.EditorChanges")
local NoteManager = require("rizu.editor.NoteManager")
local Scroller = require("rizu.editor.Scroller")
local Metronome = require("rizu.editor.Metronome")
local BmsToolsContext = require("rizu.editor.BmsToolsContext")
local EditorSession = require("rizu.editor.EditorSession")
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
	self.audio_engine = AudioEngine()
	self.ncbtContext = NcbtContext()
	self.intervalManager = IntervalManager()
	self.graphsGenerator = GraphsGenerator()
	self.editorChanges = EditorChanges()
	self.timer = TimeManager()
	self.timer:setGlobalTime(0)
	self.noteManager = NoteManager()
	self.visualEngine = VisualEngine()
	self.scroller = Scroller()
	self.metronome = Metronome()
	self.metadata = Metadata()

	for _, v in pairs(self) do
		v.editorModel = self
	end
	self.bmsToolsContext = BmsToolsContext()
	self.session = EditorSession(self)
end

function EditorModel:load()
	self.loaded = true

	local editor = self:getSettings()

	self.layer, self.notes = self.noteChartLoader:load()
	self.visual = self.layer.visuals.main or self.layer.visuals[""]

	self.session:load(self)

	self.timer:pause()
	self.timer:setTime(editor.time)

	local volume = self.configModel.configs.settings.audio.volume
	self.audio_engine:setVolume(volume.master * volume.music, volume.master * volume.keysounds)
	self.audio_engine:setAudioMode(self.configModel.configs.settings.audio.mode)

	self.metronome.volume = volume
	self.metronome:load()

	self.scroller:scrollSeconds(self.timer:getTime())

	self.bmsToolsContext:initFromLayer(self.layer)

	self.metadata:new()
	self.metadata:fromChartmeta(self.chartmeta)
end

function EditorModel:detectTempoOffset()
	self.ncbtContext:detect(self.audio_engine:renderWave())
end

function EditorModel:applyNcbt()
	self.ncbtContext:apply(self.layer)
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
	self.timer:setTime(time, true)
	self.audio_engine:setPosition(time)
end

---@return number
---@return number
function EditorModel:getIterRange()
	local editor = self:getSettings()
	local absoluteTime = self.session.point.absoluteTime
	local delta = 1 / editor.speed
	return absoluteTime - delta, absoluteTime + delta
end

---@param resources {[string]: string}
function EditorModel:loadResources(resources)
	if not self.loaded then
		return
	end

	self.audio_engine:setEnabled(true)
	self.audio_engine:load(self.chart, resources)
	self.audio_engine:setPosition(self.timer:getTime())

	self.wave = self.audio_engine:renderWave()

	self:genGraphs()

	self.resourcesLoaded = true
end

---@return number
---@return number
function EditorModel:getFirstLastTime()
	local layer = self.layer

	local firstTime = math.min(
		self.audio_engine:getStartTime(),
		layer.points:getFirstPoint():tonumber()
	)
	local lastTime = math.max(
		layer.points:getLastPoint():tonumber()
	)

	return firstTime, lastTime
end

function EditorModel:genGraphs()
	local a, b = self:getFirstLastTime()
	self.graphsGenerator:genDensityGraph(self.chart, a, b)
	self.graphsGenerator:genVerticesGraph(self.layer, a, b)
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
	self.audio_engine:unload()
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
	self.audio_engine:play()
end

function EditorModel:pause()
	self.timer:pause()
	self.audio_engine:pause()
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
	local noteSkin = self.session.noteSkin
	local editor = self:getSettings()
	return self.session.point.absoluteTime - noteSkin:getInverseTimePosition(my + dy) / editor.speed
end

---@param note rizu.editor.EditorNote
function EditorModel:selectNote(note)
	self.visualEngine:selectNote(note, love.keyboard.isDown("lctrl"))
end

function EditorModel:selectStart()
	self.visualEngine:selectStart()
	local mx, my = love.graphics.inverseTransformPoint(love.mouse.getPosition())
	self.session.selectRect = {mx, my, mx, my}
	self.session.selectStartTime = self:getMouseTime()
	just.select(mx, my, mx, my)
end

function EditorModel:selectEnd()
	self.visualEngine:selectEnd()
	self.session.selectRect = nil
	just.unselect()
end

function EditorModel:update()
	local editor = self:getSettings()
	local noteSkin = self.session.noteSkin

	local time = self.timer:getTime()
	editor.time = time

	self.noteManager:update()
	self.metronome:update()

	if self.session.selectRect then
		local mx, my = love.graphics.inverseTransformPoint(love.mouse.getPosition())
		self.session.selectRect[2] = noteSkin:getTimePosition((time - self.session.selectStartTime) * editor.speed)
		self.session.selectRect[3] = mx
		self.session.selectRect[4] = my
		just.select(self.session.selectRect[1], self.session.selectRect[2], mx, my)
	end

	local dtp = self:getDtpAbsolute(time)
	if self.intervalManager.grabbedVertex then
		self.intervalManager:moveGrabbed(time)
	end
	self.audio_engine:update()

	dtp:clone(self.session.point)

	self.visualEngine:update()
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
