local class = require("class")
local EditorInput = require("rizu.editor.EditorInput")
local EditorServices = require("rizu.editor.EditorServices")
local EditorCursorState = require("rizu.editor.EditorCursorState")
local EditorSelectionState = require("rizu.editor.EditorSelectionState")
local EditorRenderState = require("rizu.editor.EditorRenderState")
local EditorAnalysisState = require("rizu.editor.EditorAnalysisState")
local EditorRuntimeState = require("rizu.editor.EditorRuntimeState")
local EditorModelContext = require("rizu.editor.EditorModelContext")

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
---@field analysisService rizu.editor.EditorAnalysisService
---@field runtimeState rizu.editor.EditorRuntimeState
---@field viewState rizu.editor.EditorViewState
---@field frameService rizu.editor.EditorModelFrameService
---@field context rizu.editor.EditorModelContext
---@field services rizu.editor.EditorServices
local EditorModel = class()

EditorModel.tools = {"Select", "ShortNote", "LongNote", "SoundNote"}
EditorModel.states = {"info", "audio", "timings", "notes", "bms"}
EditorModel.max_snap = 192

-- Construction and input

---@param deps rizu.editor.EditorModelDeps
function EditorModel:new(deps)
	self.configModel = deps.configModel
	self.resourceModel = deps.resourceModel

	self:setInput(deps.input or EditorInput(), deps)

	local services = deps.services or EditorServices(deps)
	self.services = services
	services:applyToEditorModel(self)
	self.context = EditorModelContext(self)
	self.timer:setGlobalTime(0)
	services:attachEditorModel(self)
end

---@param input rizu.editor.EditorInput
---@param deps rizu.editor.EditorModelDeps
function EditorModel:setInput(input, deps)
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
end

-- Lifecycle

function EditorModel:load()
	self.loadService:load(self.context:getLoadContext())
end

function EditorModel:unload()
	self:setLoaded(false)
	self:setResourcesLoaded(false)
	self:setWave(nil)
	self.audio_engine:unload()
	self.metronome:unload()
end

function EditorModel:save()
	self.saveService:save(self.context:getSaveContext())
end

-- State accessors

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

-- Settings

---@param editor table
---@return table
function EditorModel:normalizeEditorSettings(editor)
	return self.settingsService:normalizeContextEditorSettings(self.context:getSettingsContext(), editor)
end

---@return table
function EditorModel:getSettings()
	return self.settingsService:getEditorSettings(self.context:getSettingsContext())
end

---@return table
function EditorModel:getAudioSettings()
	return self.settingsService:getEditorAudioSettings(self.context:getSettingsContext())
end

---@return number
function EditorModel:getLogSpeed()
	return self.settingsService:getEditorLogSpeed(self.context:getSettingsContext())
end

---@param logSpeed number
function EditorModel:setLogSpeed(logSpeed)
	self.settingsService:setEditorLogSpeed(self.context:getSettingsContext(), logSpeed)
end

function EditorModel:incSnap()
	self.settingsService:incEditorSnap(self.context:getSettingsContext())
end

function EditorModel:decSnap()
	self.settingsService:decEditorSnap(self.context:getSettingsContext())
end

---@param j number|table
---@return number
function EditorModel:getSnap(j)
	return self.settingsService:getEditorSnap(self.context:getSettingsContext(), j)
end

-- Timeline and playback

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

---@param time number
function EditorModel:setTime(time)
	self.playbackService:setEditorTime(self.context:getPlaybackContext(), time)
end

function EditorModel:play()
	self.playbackService:playEditor(self.context:getPlaybackContext())
end

function EditorModel:pause()
	self.playbackService:pauseEditor(self.context:getPlaybackContext())
end

---@return number
---@return number
function EditorModel:getIterRange()
	local editor = self:getSettings()
	local absoluteTime = self:getSessionTime()
	local delta = 1 / editor.speed
	return absoluteTime - delta, absoluteTime + delta
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

---@param point chartedit.Point
function EditorModel:scrollPoint(point)
	self.scroller:scrollPoint(point)
end

-- Resources and analysis

---@param resources {[string]: string}
function EditorModel:loadResources(resources)
	if not self:isLoaded() then
		return
	end

	self.resourceLoadService:load(self.context:getResourceLoadContext(), resources)
end

function EditorModel:genGraphs()
	self.analysisService:genGraphs(self.context:getAnalysisContext())
end

-- Editing commands

function EditorModel:undo()
	self.editorChanges:undo()
end

function EditorModel:redo()
	self.editorChanges:redo()
end

-- Selection

---@param note rizu.editor.EditorNote
function EditorModel:selectNote(note)
	self.selectionService:selectNote(self.visualEngine, self.isMultiSelectRequested, note)
end

function EditorModel:selectStart()
	self.selectionService:selectStart(self.visualEngine, self.context:getSelectionRectContext())
end

---@param mx number
---@param my number
---@param mouseTime number
function EditorModel:selectStartAt(mx, my, mouseTime)
	self.selectionService:selectStartAt(self.visualEngine, self.context:getSelectionRectContext(), mx, my, mouseTime)
end

function EditorModel:selectEnd()
	self.selectionService:selectEnd(self.visualEngine, self.context:getSelectionRectContext())
end

-- Frame/update

function EditorModel:update()
	self.frameService:update(self.context:getFrameContext())
end

---@param event table
function EditorModel:receive(event)
	self.frameService:receive(self.context:getFrameContext(), event)
end

-- Chart metadata

---@return number?
function EditorModel:getPreviewTime()
	return tonumber(self.chartmeta.preview_time)
end

return EditorModel
