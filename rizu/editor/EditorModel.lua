local class = require("class")
local EditorInput = require("rizu.editor.EditorInput")
local EditorServices = require("rizu.editor.EditorServices")
local EditorLoadService = require("rizu.editor.EditorLoadService")
local EditorSaveService = require("rizu.editor.EditorSaveService")
local EditorSessionResetService = require("rizu.editor.EditorSessionResetService")
local EditorResourceLoadService = require("rizu.editor.EditorResourceLoadService")
local EditorPlaybackService = require("rizu.editor.EditorPlaybackService")
local EditorSelectionService = require("rizu.editor.EditorSelectionService")
local EditorSettingsService = require("rizu.editor.EditorSettingsService")
local EditorHistoryService = require("rizu.editor.EditorHistoryService")
local EditorAnalysisService = require("rizu.editor.EditorAnalysisService")
local EditorCursorState = require("rizu.editor.EditorCursorState")
local EditorSelectionState = require("rizu.editor.EditorSelectionState")
local EditorRenderState = require("rizu.editor.EditorRenderState")
local EditorAnalysisState = require("rizu.editor.EditorAnalysisState")
local EditorRuntimeState = require("rizu.editor.EditorRuntimeState")
local EditorModelFrameService = require("rizu.editor.EditorModelFrameService")

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
---@field saveService rizu.editor.EditorSaveService
---@field selectionService rizu.editor.EditorSelectionService
---@field settingsService rizu.editor.EditorSettingsService
---@field historyService rizu.editor.EditorHistoryService
---@field analysisService rizu.editor.EditorAnalysisService
---@field runtimeState rizu.editor.EditorRuntimeState
---@field viewState rizu.editor.EditorViewState
---@field frameService rizu.editor.EditorModelFrameService
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

---@return rizu.editor.EditorSaveContext
function EditorModel:createSaveContext()
	return {
		metadata = self.metadata,
		setChartmeta = function(chartmeta)
			self.chartmeta = chartmeta
		end,
		noteChartLoader = self.noteChartLoader,
	}
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
		noteChartLoader = self.noteChartLoader,
		setChartData = function(layer, notes)
			self.layer = layer
			self.notes = notes
		end,
		setVisual = function(visual)
			self:setVisual(visual)
		end,
		sessionResetService = self.sessionResetService,
		createSessionResetContext = function()
			return self:createSessionResetContext()
		end,
		playbackService = self.playbackService,
		timer = self.timer,
		audio_engine = self.audio_engine,
		getAudioSettings = function()
			return self:getAudioSettings()
		end,
		configModel = self.configModel,
		metronome = self.metronome,
		scroller = self.scroller,
		bmsToolsContext = self.bmsToolsContext,
		metadata = self.metadata,
		chartmeta = self.chartmeta,
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
			(self.playbackService or EditorPlaybackService()):loadEditorAudioResources(
				self:createPlaybackContext(),
				loadedResources
			)
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

---@return rizu.editor.EditorPlaybackContext
function EditorModel:createPlaybackContext()
	return {
		timer = self.timer,
		audio_engine = self.audio_engine,
		chart = self.chart,
		intervalManager = self.intervalManager,
	}
end

---@return rizu.editor.EditorSettingsContext
function EditorModel:createSettingsContext()
	return {
		configModel = self.configModel,
		maxSnap = self.max_snap,
	}
end

---@return rizu.editor.EditorHistoryContext
function EditorModel:createHistoryContext()
	return {
		editorChanges = self.editorChanges,
	}
end

---@return rizu.editor.EditorAnalysisContext
function EditorModel:createAnalysisContext()
	return {
		ncbtContext = self.ncbtContext,
		audio_engine = self.audio_engine,
		layer = self.layer,
		chart = self.chart,
		graphsGenerator = self.graphsGenerator,
		setWave = function(wave)
			self:setWave(wave)
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
		getEditorNoteContext = function()
			return self:createEditorNoteContext()
		end,
	}
end

---@return rizu.editor.EditorNoteContext
function EditorModel:createEditorNoteContext()
	return {
		getDtpAbsolute = function(absoluteTime)
			return self:getDtpAbsolute(absoluteTime)
		end,
		getLayer = function()
			return self.layer
		end,
		getVisual = function()
			return self:getVisual()
		end,
		getNextSnapIntervalTime = function(point, delta)
			return self.scroller:getNextSnapIntervalTime(point, delta)
		end,
	}
end

---@return rizu.editor.EditorNoteServiceContext
function EditorModel:createEditorNoteServiceContext()
	return {
		columnService = {
			getMousePosition = self.getMousePosition,
			getNoteSkin = function()
				return self:getNoteSkin()
			end,
		},
		commandService = {
			getSelectedNotes = function()
				return self.visualEngine.selectedNotes
			end,
			editorChanges = self.editorChanges,
			getSettings = function()
				return self:getSettings()
			end,
			getNoteSkin = function()
				return self:getNoteSkin()
			end,
			resetVisual = function()
				self.visualEngine:reset()
			end,
			getNoteOpsContext = function()
				return {
					notes = self.notes,
					editorChanges = self.editorChanges,
					getLayer = function()
						return self.layer
					end,
					getVisual = function()
						return self:getVisual()
					end,
				}
			end,
		},
		dragService = {
			getNoteSkin = function()
				return self:getNoteSkin()
			end,
			getSettings = function()
				return self:getSettings()
			end,
			editorChanges = self.editorChanges,
			getSelectedNotes = function()
				return self.visualEngine.selectedNotes
			end,
			getMouseTime = function()
				return self:getMouseTime()
			end,
		},
		clipboardService = {
			getSelectedNotes = function()
				return self.visualEngine.selectedNotes
			end,
			editorChanges = self.editorChanges,
			getPoint = function()
				return self:getPoint()
			end,
		},
		createService = {
			getVisualInfo = function()
				return self.visualEngine.visual_info
			end,
			getEditorNoteContext = function()
				return self:createEditorNoteContext()
			end,
			getVisualEngine = function()
				return self.visualEngine
			end,
			getSettings = function()
				return self:getSettings()
			end,
			selectNote = function(note)
				self.visualEngine:selectNote(note)
			end,
			getMouseTime = function()
				return self:getMouseTime()
			end,
		},
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

function EditorModel:detectTempoOffset()
	(self.analysisService or EditorAnalysisService()):detectTempoOffset(self:createAnalysisContext())
end

function EditorModel:applyNcbt()
	(self.analysisService or EditorAnalysisService()):applyNcbt(self:createAnalysisContext())
end

---@param editor table
---@return table
function EditorModel:normalizeEditorSettings(editor)
	return (self.settingsService or EditorSettingsService()):normalizeContextEditorSettings(
		self:createSettingsContext(),
		editor
	)
end

---@return table
function EditorModel:getSettings()
	return (self.settingsService or EditorSettingsService()):getEditorSettings(self:createSettingsContext())
end

---@return table
function EditorModel:getAudioSettings()
	return (self.settingsService or EditorSettingsService()):getEditorAudioSettings(self:createSettingsContext())
end

function EditorModel:undo()
	(self.historyService or EditorHistoryService()):undo(self:createHistoryContext())
end

function EditorModel:redo()
	(self.historyService or EditorHistoryService()):redo(self:createHistoryContext())
end

---@param time number
function EditorModel:setTime(time)
	(self.playbackService or EditorPlaybackService()):setEditorTime(self:createPlaybackContext(), time)
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
	(self.playbackService or EditorPlaybackService()):loadEditorAudioResources(self:createPlaybackContext(), resources)
end

function EditorModel:renderWave()
	(self.analysisService or EditorAnalysisService()):renderWave(self:createAnalysisContext())
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
	return (self.analysisService or EditorAnalysisService()):getFirstLastTime(self:createAnalysisContext())
end

---@return number
---@return number
function EditorModel:getTimelineRange()
	return (self.analysisService or EditorAnalysisService()):getTimelineRange(self:createAnalysisContext())
end

function EditorModel:genGraphs()
	(self.analysisService or EditorAnalysisService()):genGraphs(self:createAnalysisContext())
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
	(self.saveService or EditorSaveService()):save(self:createSaveContext())
end

function EditorModel:play()
	(self.playbackService or EditorPlaybackService()):playEditor(self:createPlaybackContext())
end

function EditorModel:pause()
	(self.playbackService or EditorPlaybackService()):pauseEditor(self:createPlaybackContext())
end

---@return number
function EditorModel:getLogSpeed()
	return (self.settingsService or EditorSettingsService()):getEditorLogSpeed(self:createSettingsContext())
end

---@param logSpeed number
function EditorModel:setLogSpeed(logSpeed)
	(self.settingsService or EditorSettingsService()):setEditorLogSpeed(self:createSettingsContext(), logSpeed)
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

function EditorModel:update()
	(self.frameService or EditorModelFrameService()):update(self:createFrameContext())
end

---@param event table
function EditorModel:receive(event)
	(self.frameService or EditorModelFrameService()):receive(self:createFrameContext(), event)
end

---@return rizu.editor.EditorModelFrameContext
function EditorModel:createFrameContext()
	return {
		timer = self.timer,
		services = self.services,
		noteService = self.noteService,
		metronome = self.metronome,
		selectionService = self.selectionService,
		playbackService = self.playbackService,
		audio_engine = self.audio_engine,
		intervalManager = self.intervalManager,
		visualEngine = self.visualEngine,
		getSettings = function()
			return self:getSettings()
		end,
		getNoteSkin = function()
			return self:getNoteSkin()
		end,
		getDtpAbsolute = function(time)
			return self:getDtpAbsolute(time)
		end,
		setSessionPoint = function(point)
			self:setSessionPoint(point)
		end,
		createSelectionRectContext = function()
			return self:createSelectionRectContext()
		end,
	}
end

function EditorModel:incSnap()
	(self.settingsService or EditorSettingsService()):incEditorSnap(self:createSettingsContext())
end

function EditorModel:decSnap()
	(self.settingsService or EditorSettingsService()):decEditorSnap(self:createSettingsContext())
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
	return (self.settingsService or EditorSettingsService()):getEditorSnap(self:createSettingsContext(), j)
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
