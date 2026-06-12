local class = require("class")
local EditorInput = require("rizu.editor.EditorInput")
local EditorServices = require("rizu.editor.EditorServices")
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

---@class rizu.editor.EditorModelDeps: rizu.editor.EditorServicesDeps
---@field services rizu.editor.EditorServices?
---@field configModel sphere.ConfigModel
---@field resourceModel sphere.ResourceModel
---@field input rizu.editor.EditorInput?
---@field isMultiSelectRequested (fun(): boolean)?
---@field getMousePosition (fun(): number, number)?
---@field selectRegion (fun(x1: number, y1: number, x2: number, y2: number))?
---@field unselectRegion (fun())?
---@field isEditorCommandRequested (fun(): boolean)?
---@field isFineScrollRequested (fun(): boolean)?
---@field isSnapChangeRequested (fun(): boolean)?
---@field isSpeedChangeRequested (fun(): boolean)?
---@field fs fs.IFilesystem?

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
---@field services rizu.editor.EditorServices
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

	local services = deps.services or EditorServices(deps)
	self.services = services
	services:applyToEditorModel(self)
	self.timer:setGlobalTime(0)
	services:attachEditorModel(self)
end

function EditorModel:load()
	local loadService = self.loadService or EditorLoadService()
	loadService:load(self:createLoadContext())
end

---@return rizu.editor.EditorLoadContext
function EditorModel:createLoadContext()
	return {
		setLoaded = function(loaded)
			self:setLoaded(loaded)
		end,
		getSettings = function()
			return self:getSettings()
		end,
		loadChartData = function()
			self:loadChartData()
		end,
		resetState = function()
			self:resetState()
		end,
		loadTimer = function(editor)
			self:loadTimer(editor)
		end,
		loadAudio = function()
			self:loadAudio()
		end,
		loadMetronome = function()
			self:loadMetronome()
		end,
		loadInitialScroll = function()
			self:loadInitialScroll()
		end,
		loadBmsToolsContext = function()
			self:loadBmsToolsContext()
		end,
		loadMetadata = function()
			self:loadMetadata()
		end,
	}
end

---@return rizu.editor.EditorSessionResetContext
function EditorModel:createSessionResetContext()
	local newChanges = self.sessionResetService.newChanges or EditorSessionResetService.newChanges
	return {
		analyzePatterns = function()
			self:analyzePatterns()
		end,
		newChanges = newChanges,
		setChanges = function(changes)
			self:setChanges(changes)
		end,
		loadGraphs = function()
			self.graphsGenerator:load()
		end,
		setResourcesLoaded = function(loaded)
			self:setResourcesLoaded(loaded)
		end,
		setSessionTime = function(time)
			self:setSessionTime(time)
		end,
		finishSelection = function()
			self:getSelectionState():finish()
		end,
	}
end

---@return rizu.editor.EditorResourceLoadContext
function EditorModel:createResourceLoadContext()
	return {
		loadAudioResources = function(loadedResources)
			self:loadAudioResources(loadedResources)
		end,
		renderWave = function()
			self:renderWave()
		end,
		genGraphs = function()
			self:genGraphs()
		end,
		setResourcesLoaded = function(loaded)
			self:setResourcesLoaded(loaded)
		end,
	}
end

---@return rizu.editor.EditorSelectionRectContext
function EditorModel:createSelectionRectContext()
	return {
		selectionState = self:getSelectionState(),
		getMousePosition = self.getMousePosition,
		getMouseTime = function()
			return self:getMouseTime()
		end,
		selectRegion = self.selectRegion,
		unselectRegion = self.unselectRegion,
	}
end

---@return rizu.editor.ScrollerContext
function EditorModel:createScrollerContext()
	return {
		getDtpAbsolute = function(absoluteTime)
			return self:getDtpAbsolute(absoluteTime)
		end,
		getSessionTime = function()
			return self:getSessionTime()
		end,
		getPoint = function()
			return self:getPoint()
		end,
		setSessionPoint = function(point)
			self:setSessionPoint(point)
		end,
		setTime = function(time)
			self:setTime(time)
		end,
		isIntervalGrabbed = function()
			return self.intervalManager:isGrabbed()
		end,
		interpolateFraction = function(vertex, time)
			return self.layer.points:interpolateFraction(vertex, time)
		end,
		getSettings = function()
			return self:getSettings()
		end,
	}
end

---@return rizu.editor.IntervalManagerContext
function EditorModel:createIntervalManagerContext()
	return {
		getLayer = function()
			return self.layer
		end,
		getNotes = function()
			return self.notes
		end,
		editorChanges = self.editorChanges,
	}
end

---@return rizu.editor.EditorChangesContext
function EditorModel:createEditorChangesContext()
	return {
		resetVisual = function()
			self.visualEngine:reset()
		end,
	}
end

---@return rizu.editor.NoteChartLoaderContext
function EditorModel:createNoteChartLoaderContext()
	return {
		getChart = function()
			return self.chart
		end,
		getLayer = function()
			return self.layer
		end,
		getNotes = function()
			return self.notes
		end,
	}
end

---@return rizu.editor.VisualEngineContext
function EditorModel:createVisualEngineContext()
	return {
		getSessionTime = function()
			return self:getSessionTime()
		end,
		getEditorSettings = function()
			return self.configModel.configs.settings.editor
		end,
		getVisualPoint = function()
			return self.visualPoint
		end,
		getVisual = function()
			return self:getVisual()
		end,
		getNotes = function()
			return self.notes
		end,
		getIterRange = function()
			return self:getIterRange()
		end,
		getEditorModel = function()
			return self
		end,
	}
end

---@return rizu.editor.MetronomeContext
function EditorModel:createMetronomeContext()
	return {
		getPoint = function()
			return self:getPoint()
		end,
		getCurrentTime = function()
			return self.timer:getTime()
		end,
		getNextSnapIntervalTime = function(point, delta)
			return self.scroller:getNextSnapIntervalTime(point, delta)
		end,
		interpolateFraction = function(vertex, time)
			return self.layer.points:interpolateFraction(vertex, time)
		end,
	}
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
	self.sessionResetService:reset(self:createSessionResetContext())
end

---@param editor table
function EditorModel:loadTimer(editor)
	(self.playbackService or EditorPlaybackService()):loadTimer(self.timer, editor)
end

function EditorModel:loadAudio()
	(self.playbackService or EditorPlaybackService()):loadAudio(self.audio_engine, self:getAudioSettings())
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
	return (self.settingsService or EditorSettingsService()):getSettings(self.configModel, self.max_snap)
end

---@return table
function EditorModel:getAudioSettings()
	return (self.settingsService or EditorSettingsService()):getAudioSettings(self.configModel)
end

function EditorModel:undo()
	self.editorChanges:undo()
end

function EditorModel:redo()
	self.editorChanges:redo()
end

---@param time number
function EditorModel:setTime(time)
	(self.playbackService or EditorPlaybackService()):setTime(self.timer, self.audio_engine, time)
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
	resourceLoadService:load(self:createResourceLoadContext(), resources)
end

---@param resources {[string]: string}
function EditorModel:loadAudioResources(resources)
	(self.playbackService or EditorPlaybackService()):loadAudioResources(self.audio_engine, self.timer, self.chart, resources)
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
	(self.playbackService or EditorPlaybackService()):play(self.timer, self.audio_engine, function()
		return self.intervalManager:isGrabbed()
	end)
end

function EditorModel:pause()
	(self.playbackService or EditorPlaybackService()):pause(self.timer, self.audio_engine)
end

---@return number
function EditorModel:getLogSpeed()
	return (self.settingsService or EditorSettingsService()):getLogSpeed(self:getSettings())
end

---@param logSpeed number
function EditorModel:setLogSpeed(logSpeed)
	(self.settingsService or EditorSettingsService()):setLogSpeed(self:getSettings(), logSpeed)
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
	(self.selectionService or EditorSelectionService()):selectNote(self.visualEngine, self.isMultiSelectRequested, note)
end

function EditorModel:selectStart()
	(self.selectionService or EditorSelectionService()):selectStart(self.visualEngine, self:createSelectionRectContext())
end

function EditorModel:selectEnd()
	(self.selectionService or EditorSelectionService()):selectEnd(self.visualEngine, self:createSelectionRectContext())
end

---@param editor table
---@param time number
function EditorModel:updateEditorTime(editor, time)
	editor.time = time
end

function EditorModel:updateServices()
	if self.services then
		self.services:update()
		return
	end
	self.noteService:update()
	self.metronome:update()
end

---@param editor table
---@param noteSkin table
---@param time number
function EditorModel:updateSelectionRect(editor, noteSkin, time)
	(self.selectionService or EditorSelectionService()):updateSelectionRect(self:createSelectionRectContext(), editor, noteSkin, time)
end

---@param time number
function EditorModel:updateTimingDrag(time)
	if self.intervalManager.grabbedVertex then
		self.intervalManager:moveGrabbed(time)
	end
end

function EditorModel:updateAudio()
	(self.playbackService or EditorPlaybackService()):updateAudio(self.audio_engine)
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

	self:updateServices()
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
	(self.settingsService or EditorSettingsService()):incSnap(self:getSettings(), self.max_snap)
end

function EditorModel:decSnap()
	(self.settingsService or EditorSettingsService()):decSnap(self:getSettings(), self.max_snap)
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
	return (self.settingsService or EditorSettingsService()):getSnap(self:getSettings(), j)
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
