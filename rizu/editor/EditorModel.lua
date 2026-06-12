local class = require("class")
local AudioEngine = require("rizu.engine.audio.Engine")
local TimeManager = require("rizu.editor.TimeManager")
local VisualEngine = require("rizu.editor.VisualEngine")
local NoteChartLoader = require("rizu.editor.NoteChartLoader")
local NcbtContext = require("rizu.editor.NcbtContext")
local IntervalManager = require("rizu.editor.IntervalManager")
local GraphsGenerator = require("rizu.editor.GraphsGenerator")
local EditorChanges = require("rizu.editor.EditorChanges")
local EditorInput = require("rizu.editor.EditorInput")
local EditorLoadService = require("rizu.editor.EditorLoadService")
local EditorSessionResetService = require("rizu.editor.EditorSessionResetService")
local EditorResourceLoadService = require("rizu.editor.EditorResourceLoadService")
local EditorPlaybackService = require("rizu.editor.EditorPlaybackService")
local EditorSelectionService = require("rizu.editor.EditorSelectionService")
local EditorSettingsService = require("rizu.editor.EditorSettingsService")
local EditorCursorState = require("rizu.editor.EditorCursorState")
local EditorSelectionState = require("rizu.editor.EditorSelectionState")
local EditorRenderState = require("rizu.editor.EditorRenderState")
local EditorAnalysisState = require("rizu.editor.EditorAnalysisState")
local EditorRuntimeState = require("rizu.editor.EditorRuntimeState")
local EditorViewState = require("rizu.editor.EditorViewState")
local EditorNoteService = require("rizu.editor.EditorNoteService")
local Scroller = require("rizu.editor.Scroller")
local Metronome = require("rizu.editor.Metronome")
local BmsToolsContext = require("rizu.editor.BmsToolsContext")
local Metadata = require("chart.format.sph.Metadata")

---@class rizu.editor.EditorModelDeps
---@field configModel sphere.ConfigModel
---@field resourceModel sphere.ResourceModel
---@field fs fs.IFilesystem?
---@field input rizu.editor.EditorInput?
---@field isMultiSelectRequested (fun(): boolean)?
---@field getMousePosition (fun(): number, number)?
---@field selectRegion (fun(x1: number, y1: number, x2: number, y2: number))?
---@field unselectRegion (fun())?
---@field isEditorCommandRequested (fun(): boolean)?
---@field isFineScrollRequested (fun(): boolean)?
---@field isSnapChangeRequested (fun(): boolean)?
---@field isSpeedChangeRequested (fun(): boolean)?
---@field noteChartLoader rizu.editor.EditorNoteChartLoader?
---@field audio_engine rizu.engine.audio.Engine?
---@field ncbtContext rizu.editor.NcbtContext?
---@field intervalManager rizu.editor.IntervalManager?
---@field graphsGenerator rizu.editor.GraphsGenerator?
---@field editorChanges rizu.editor.EditorChanges?
---@field timer rizu.editor.TimeManager?
---@field noteService rizu.editor.EditorNoteService?
---@field visualEngine rizu.editor.VisualEngine?
---@field scroller rizu.editor.Scroller?
---@field metronome rizu.editor.Metronome?
---@field metadata chart.sph.Metadata?
---@field bmsToolsContext rizu.editor.BmsToolsContext?
---@field loadService rizu.editor.EditorLoadService?
---@field sessionResetService rizu.editor.EditorSessionResetService?
---@field resourceLoadService rizu.editor.EditorResourceLoadService?
---@field playbackService rizu.editor.EditorPlaybackService?
---@field selectionService rizu.editor.EditorSelectionService?
---@field settingsService rizu.editor.EditorSettingsService?
---@field cursorState rizu.editor.EditorCursorState?
---@field selectionState rizu.editor.EditorSelectionState?
---@field renderState rizu.editor.EditorRenderState?
---@field analysisState rizu.editor.EditorAnalysisState?
---@field runtimeState rizu.editor.EditorRuntimeState?
---@field viewState rizu.editor.EditorViewState?

---@class rizu.editor.EditorModel
---@operator call: rizu.editor.EditorModel
---@field layer chartedit.Layer
---@field isMultiSelectRequested fun(): boolean
---@field getMousePosition fun(): number, number
---@field selectRegion fun(x1: number, y1: number, x2: number, y2: number)
---@field unselectRegion fun()
---@field isEditorCommandRequested fun(): boolean
---@field isFineScrollRequested fun(): boolean
---@field isSnapChangeRequested fun(): boolean
---@field isSpeedChangeRequested fun(): boolean
---@field cursorState rizu.editor.EditorCursorState
---@field selectionState rizu.editor.EditorSelectionState
---@field renderState rizu.editor.EditorRenderState
---@field analysisState rizu.editor.EditorAnalysisState
---@field playbackService rizu.editor.EditorPlaybackService
---@field selectionService rizu.editor.EditorSelectionService
---@field settingsService rizu.editor.EditorSettingsService
---@field runtimeState rizu.editor.EditorRuntimeState
---@field viewState rizu.editor.EditorViewState
local EditorModel = class()

EditorModel.tools = {"Select", "ShortNote", "LongNote", "SoundNote"}
EditorModel.states = {"info", "audio", "timings", "notes", "bms"}
EditorModel.max_snap = 192

---@param deps rizu.editor.EditorModelDeps
function EditorModel:new(deps)
	self.configModel = deps.configModel
	self.resourceModel = deps.resourceModel

	local input = deps.input or EditorInput()
	self.input = input
	self.isMultiSelectRequested = deps.isMultiSelectRequested or function()
		return input:isMultiSelectRequested()
	end
	self.getMousePosition = deps.getMousePosition or function()
		return input:getMousePosition()
	end
	self.selectRegion = deps.selectRegion or function(x1, y1, x2, y2)
		input:selectRegion(x1, y1, x2, y2)
	end
	self.unselectRegion = deps.unselectRegion or function()
		input:unselectRegion()
	end
	self.isEditorCommandRequested = deps.isEditorCommandRequested or function()
		return input:isEditorCommandRequested()
	end
	self.isFineScrollRequested = deps.isFineScrollRequested or function()
		return input:isFineScrollRequested()
	end
	self.isSnapChangeRequested = deps.isSnapChangeRequested or function()
		return input:isSnapChangeRequested()
	end
	self.isSpeedChangeRequested = deps.isSpeedChangeRequested or function()
		return input:isSpeedChangeRequested()
	end

	self.noteChartLoader = deps.noteChartLoader or NoteChartLoader()
	self.audio_engine = deps.audio_engine or AudioEngine()
	self.ncbtContext = deps.ncbtContext or NcbtContext()
	self.intervalManager = deps.intervalManager or IntervalManager()
	self.graphsGenerator = deps.graphsGenerator or GraphsGenerator()
	self.editorChanges = deps.editorChanges or EditorChanges()
	self.timer = deps.timer or TimeManager()
	self.timer:setGlobalTime(0)
	self.noteService = deps.noteService or EditorNoteService()
	self.visualEngine = deps.visualEngine or VisualEngine()
	self.scroller = deps.scroller or Scroller()
	self.metronome = deps.metronome or Metronome(deps.fs)
	self.metadata = deps.metadata or Metadata()
	self.bmsToolsContext = deps.bmsToolsContext or BmsToolsContext()
	self.cursorState = deps.cursorState or EditorCursorState()
	self.selectionState = deps.selectionState or EditorSelectionState()
	self.renderState = deps.renderState or EditorRenderState()
	self.analysisState = deps.analysisState or EditorAnalysisState()
	self.loadService = deps.loadService or EditorLoadService()
	self.sessionResetService = deps.sessionResetService or EditorSessionResetService()
	self.resourceLoadService = deps.resourceLoadService or EditorResourceLoadService()
	self.playbackService = deps.playbackService or EditorPlaybackService()
	self.selectionService = deps.selectionService or EditorSelectionService()
	self.settingsService = deps.settingsService or EditorSettingsService()
	self.runtimeState = deps.runtimeState or EditorRuntimeState()
	self.viewState = deps.viewState or EditorViewState()

	self:attachManagers()
end

function EditorModel:attachManagers()
	self.noteChartLoader.editorModel = self
	self.ncbtContext.editorModel = self
	self.intervalManager.editorModel = self
	self.graphsGenerator.editorModel = self
	self.editorChanges.editorModel = self
	if self.noteService.setEditorModel then
		self.noteService:setEditorModel(self)
	else
		self.noteService.editorModel = self
	end
	self.visualEngine.editorModel = self
	self.scroller.editorModel = self
	self.metronome.editorModel = self
	self.bmsToolsContext.editorModel = self
end

function EditorModel:load()
	local loadService = self.loadService or EditorLoadService()
	loadService:load(self)
end

---@return rizu.editor.EditorRuntimeState
function EditorModel:getRuntimeState()
	local runtimeState = self.runtimeState
	if not runtimeState then
		runtimeState = EditorRuntimeState()
		self.runtimeState = runtimeState
	end
	return runtimeState
end

---@return rizu.editor.EditorCursorState
function EditorModel:getCursorState()
	local cursorState = self.cursorState
	if not cursorState then
		cursorState = EditorCursorState()
		self.cursorState = cursorState
	end
	return cursorState
end

---@return rizu.editor.EditorSelectionState
function EditorModel:getSelectionState()
	local selectionState = self.selectionState
	if not selectionState then
		selectionState = EditorSelectionState()
		self.selectionState = selectionState
	end
	return selectionState
end

---@return rizu.editor.EditorRenderState
function EditorModel:getRenderState()
	local renderState = self.renderState
	if not renderState then
		renderState = EditorRenderState()
		self.renderState = renderState
	end
	return renderState
end

---@return rizu.editor.EditorAnalysisState
function EditorModel:getAnalysisState()
	local analysisState = self.analysisState
	if not analysisState then
		analysisState = EditorAnalysisState()
		self.analysisState = analysisState
	end
	return analysisState
end

function EditorModel:analyzePatterns()
	self:getAnalysisState():analyze(self.chart)
end

---@return string?
function EditorModel:getPatternsAnalyzed()
	return self:getAnalysisState():getPatternsAnalyzed()
end

---@param noteSkin table?
function EditorModel:setNoteSkin(noteSkin)
	self:getRenderState():setNoteSkin(noteSkin)
end

---@return table?
function EditorModel:getNoteSkin()
	return self:getRenderState():getNoteSkin()
end

function EditorModel:loadChartData()
	self.layer, self.notes = self.noteChartLoader:load()
	self:setVisual(self.layer.visuals.main or self.layer.visuals[""])
end

function EditorModel:resetState()
	self.sessionResetService:reset(self)
end

---@param editor table
function EditorModel:loadTimer(editor)
	(self.playbackService or EditorPlaybackService()):loadTimer(self, editor)
end

function EditorModel:loadAudio()
	(self.playbackService or EditorPlaybackService()):loadAudio(self)
end

function EditorModel:loadMetronome()
	local volume = self.configModel.configs.settings.audio.volume
	self.metronome.volume = volume
	self.metronome:load()
end

function EditorModel:loadInitialScroll()
	self.scroller:scrollSeconds(self.timer:getTime())
end

function EditorModel:loadBmsToolsContext()
	self.bmsToolsContext:initFromLayer(self.layer)
end

function EditorModel:loadMetadata()
	self.metadata:new()
	self.metadata:fromChartmeta(self.chartmeta)
end

function EditorModel:detectTempoOffset()
	self.ncbtContext:detect(self.audio_engine:renderWave())
end

function EditorModel:applyNcbt()
	self.ncbtContext:apply(self.layer)
end

---@param editor table
---@return table
function EditorModel:normalizeEditorSettings(editor)
	return (self.settingsService or EditorSettingsService()):normalizeEditorSettings(editor, self.max_snap)
end

---@return table
function EditorModel:getSettings()
	return (self.settingsService or EditorSettingsService()):getSettings(self)
end

---@return table
function EditorModel:getAudioSettings()
	return (self.settingsService or EditorSettingsService()):getAudioSettings(self)
end

function EditorModel:undo()
	self.editorChanges:undo()
end

function EditorModel:redo()
	self.editorChanges:redo()
end

---@param time number
function EditorModel:setTime(time)
	(self.playbackService or EditorPlaybackService()):setTime(self, time)
end

---@return number
---@return number
function EditorModel:getIterRange()
	local editor = self:getSettings()
	local absoluteTime = self:getSessionTime()
	local delta = 1 / editor.speed
	return absoluteTime - delta, absoluteTime + delta
end

---@param resources {[string]: string}
function EditorModel:loadResources(resources)
	if not self:isLoaded() then
		return
	end

	local resourceLoadService = self.resourceLoadService or EditorResourceLoadService()
	resourceLoadService:load(self, resources)
end

---@param resources {[string]: string}
function EditorModel:loadAudioResources(resources)
	(self.playbackService or EditorPlaybackService()):loadAudioResources(self, resources)
end

function EditorModel:renderWave()
	self:setWave(self.audio_engine:renderWave())
end

---@param loaded boolean
function EditorModel:setLoaded(loaded)
	self:getRuntimeState():setLoaded(loaded)
end

---@return boolean
function EditorModel:isLoaded()
	return self:getRuntimeState():isLoaded()
end

---@param loaded boolean
function EditorModel:setResourcesLoaded(loaded)
	self:getRuntimeState():setResourcesLoaded(loaded)
end

---@return boolean
function EditorModel:isResourcesLoaded()
	return self:getRuntimeState():isResourcesLoaded()
end

---@param visual chartedit.Visual?
function EditorModel:setVisual(visual)
	self:getRuntimeState():setVisual(visual)
end

---@return chartedit.Visual?
function EditorModel:getVisual()
	return self:getRuntimeState():getVisual()
end

---@param wave table?
function EditorModel:setWave(wave)
	self:getRuntimeState():setWave(wave)
end

---@return table?
function EditorModel:getWave()
	return self:getRuntimeState():getWave()
end

---@param changes Changes?
function EditorModel:setChanges(changes)
	self:getRuntimeState():setChanges(changes)
end

---@return Changes?
function EditorModel:getChanges()
	return self:getRuntimeState():getChanges()
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

---@return number
---@return number
function EditorModel:getTimelineRange()
	return self:getFirstLastTime()
end

function EditorModel:genGraphs()
	local a, b = self:getTimelineRange()
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

---@return number
function EditorModel:getSessionTime()
	return self:getCursorState():getTime()
end

---@param time number
function EditorModel:setSessionTime(time)
	self:getCursorState():setPoint(self:getDtpAbsolute(time))
end

---@param point chartedit.Point
function EditorModel:setSessionPoint(point)
	self:getCursorState():setPoint(point)
end

---@return chartedit.Point
function EditorModel:getPoint()
	return self:getCursorState():getPoint()
end

function EditorModel:unload()
	self:setLoaded(false)
	self:setResourcesLoaded(false)
	self:setWave(nil)
	self.audio_engine:unload()
	self.metronome:unload()
end

function EditorModel:save()
	self.chartmeta = self.metadata:toChartmeta()
	self.noteChartLoader:save()
end

function EditorModel:play()
	(self.playbackService or EditorPlaybackService()):play(self)
end

function EditorModel:pause()
	(self.playbackService or EditorPlaybackService()):pause(self)
end

---@return number
function EditorModel:getLogSpeed()
	return (self.settingsService or EditorSettingsService()):getLogSpeed(self)
end

---@param logSpeed number
function EditorModel:setLogSpeed(logSpeed)
	(self.settingsService or EditorSettingsService()):setLogSpeed(self, logSpeed)
end

---@param dy number?
---@return number
function EditorModel:getMouseTime(dy)
	dy = dy or 0
	local _mx, my = self.getMousePosition()
	local noteSkin = assert(self:getNoteSkin())
	local editor = self:getSettings()
	return self:getSessionTime() - noteSkin:getInverseTimePosition(my + dy) / editor.speed
end

---@param note rizu.editor.EditorNote
function EditorModel:selectNote(note)
	(self.selectionService or EditorSelectionService()):selectNote(self, note)
end

function EditorModel:selectStart()
	(self.selectionService or EditorSelectionService()):selectStart(self)
end

function EditorModel:selectEnd()
	(self.selectionService or EditorSelectionService()):selectEnd(self)
end

---@param editor table
---@param time number
function EditorModel:updateEditorTime(editor, time)
	editor.time = time
end

function EditorModel:updateManagers()
	self.noteService:update()
	self.metronome:update()
end

---@param editor table
---@param noteSkin table
---@param time number
function EditorModel:updateSelectionRect(editor, noteSkin, time)
	(self.selectionService or EditorSelectionService()):updateSelectionRect(self, editor, noteSkin, time)
end

---@param time number
function EditorModel:updateTimingDrag(time)
	if self.intervalManager.grabbedVertex then
		self.intervalManager:moveGrabbed(time)
	end
end

function EditorModel:updateAudio()
	(self.playbackService or EditorPlaybackService()):updateAudio(self)
end

---@param point chartedit.Point
function EditorModel:updateSessionPoint(point)
	self:setSessionPoint(point)
end

function EditorModel:updateVisuals()
	self.visualEngine:update()
end

function EditorModel:update()
	local editor = self:getSettings()
	local noteSkin = assert(self:getNoteSkin())

	local time = self.timer:getTime()
	self:updateEditorTime(editor, time)

	self:updateManagers()
	self:updateSelectionRect(editor, noteSkin, time)

	local dtp = self:getDtpAbsolute(time)
	self:updateTimingDrag(time)
	self:updateAudio()
	self:updateSessionPoint(dtp)
	self:updateVisuals()
end

---@param event table
function EditorModel:receive(event)
	if event.name == "framestarted" then
		local timer = self.timer
		timer:setGlobalTime(event.time)
	end
end

function EditorModel:incSnap()
	(self.settingsService or EditorSettingsService()):incSnap(self)
end

function EditorModel:decSnap()
	(self.settingsService or EditorSettingsService()):decSnap(self)
end

---@return number?
function EditorModel:getPreviewTime()
	return tonumber(self.chartmeta.preview_time)
end

---@param point chartedit.Point
function EditorModel:scrollPoint(point)
	self.scroller:scrollPoint(point)
end

---@param j number|table
---@return number
function EditorModel:getSnap(j)
	return (self.settingsService or EditorSettingsService()):getSnap(self, j)
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
