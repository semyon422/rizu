local class = require("class")

---@class rizu.editor.EditorViewContext: rizu.editor.EditorSelectionRectContext, rizu.editor.EditorModelFrameContext, rizu.editor.EditorSettingsContext, rizu.editor.VisualEngineContext, rizu.editor.EditorChangesContext, rizu.editor.EditorOverlayActionContext, rizu.editor.EditorOverlayShellContext, rizu.editor.EditorScrollInputContext, rizu.editor.EditorChartSliderContext, rizu.editor.EditorFooterContext, rizu.editor.EditorWaveformContext, rizu.editor.EditorOnsetsContext, rizu.editor.EditorTimingOverlayContext, rizu.editor.EditorAudioOverlayContext, rizu.editor.EditorAudioSettingsOverlayContext, rizu.editor.EditorNotesOverlayContext, rizu.editor.EditorPlayfieldContext
---@operator call: rizu.editor.EditorViewContext
---@field model rizu.editor.EditorModel
local EditorViewContext = class()

---@param model rizu.editor.EditorModel
function EditorViewContext:new(model)
	self.model = model
end

---@return rizu.editor.EditorSelectionState
function EditorViewContext:getSelectionState()
	return self.model:getSelectionState()
end

---@return number
---@return number
function EditorViewContext:getMousePosition()
	return self.model.getMousePosition()
end

---@return number
function EditorViewContext:getMouseTime()
	return self.model:getMouseTime()
end

---@param x1 number
---@param y1 number
---@param x2 number
---@param y2 number
function EditorViewContext:selectRegion(x1, y1, x2, y2)
	self.model.selectRegion(x1, y1, x2, y2)
end

function EditorViewContext:unselectRegion()
	self.model.unselectRegion()
end

---@param note rizu.editor.EditorNote
function EditorViewContext:selectNote(note)
	self.model:selectNote(note)
end

function EditorViewContext:selectStart()
	self.model:selectStart()
end

---@param mx number
---@param my number
---@param mouseTime number
function EditorViewContext:selectStartAt(mx, my, mouseTime)
	self.model:selectStartAt(mx, my, mouseTime)
end

function EditorViewContext:selectEnd()
	self.model:selectEnd()
end

---@return table
function EditorViewContext:getSettings()
	return self.model:getSettings()
end

---@return table
function EditorViewContext:getEditorSettings()
	return self.model.configModel.configs.settings.editor
end

---@return table
function EditorViewContext:getAudioSettings()
	return self.model.configModel.configs.settings.audio
end

---@return table?
function EditorViewContext:getNoteSkin()
	return self.model:getNoteSkin()
end

---@return table?
function EditorViewContext:getWave()
	return self.model:getWave()
end

---@return rizu.editor.TimeManager
function EditorViewContext:getTimer()
	return self.model.timer
end

---@return rizu.editor.EditorNoteService
function EditorViewContext:getNoteService()
	return self.model.noteService
end

---@return rizu.editor.EditorViewState
function EditorViewContext:getViewState()
	return self.model.viewState
end

---@return string[]
function EditorViewContext:getOverlayTabs()
	return self.model.states
end

---@return boolean
function EditorViewContext:isResourcesLoaded()
	return self.model:isResourcesLoaded()
end

---@return rizu.editor.Metronome
function EditorViewContext:getMetronome()
	return self.model.metronome
end

---@return rizu.editor.EditorSelectionService
function EditorViewContext:getSelectionService()
	return self.model.selectionService
end

---@param absoluteTime number
---@return chartedit.Point?
function EditorViewContext:getDtpAbsolute(absoluteTime)
	return self.model:getDtpAbsolute(absoluteTime)
end

---@return rizu.editor.IntervalManager
function EditorViewContext:getIntervalManager()
	return self.model.intervalManager
end

---@return rizu.editor.EditorPlaybackService
function EditorViewContext:getPlaybackService()
	return self.model.playbackService
end

---@return rizu.engine.audio.Engine
function EditorViewContext:getAudioEngine()
	return self.model.audio_engine
end

---@return number
function EditorViewContext:getAudioStartTime()
	return self.model.audio_engine:getStartTime()
end

---@return number
function EditorViewContext:getTimerTime()
	return self.model.timer:getTime()
end

---@param point chartedit.Point
function EditorViewContext:setSessionPoint(point)
	self.model:setSessionPoint(point)
end

---@return rizu.editor.VisualEngine
function EditorViewContext:getVisualEngine()
	return self.model.visualEngine
end

---@return {[chart.Note]: rizu.editor.EditorNote}
function EditorViewContext:getSelectedNotes()
	return self.model.visualEngine.selectedNotes
end

---@return sphere.ConfigModel
function EditorViewContext:getConfigModel()
	return self.model.configModel
end

---@return integer
function EditorViewContext:getMaxSnap()
	return self.model.max_snap
end

---@return string[]
function EditorViewContext:getTools()
	return self.model.tools
end

---@return number
function EditorViewContext:getSessionTime()
	return self.model:getSessionTime()
end

---@return chartedit.Point
function EditorViewContext:getPoint()
	return self.model:getPoint()
end

---@return table
function EditorViewContext:getChartmeta()
	return self.model.chartmeta
end

---@return chartedit.Point?
function EditorViewContext:getVisualPoint()
	return self.model.visualPoint
end

---@return chartedit.Visual?
function EditorViewContext:getVisual()
	return self.model:getVisual()
end

---@param point chartedit.Point
---@return chartedit.VisualPoint
function EditorViewContext:getVisualPointFor(point)
	return self.model:getVisual():getPoint(point)
end

---@return chartedit.Notes
function EditorViewContext:getNotes()
	return self.model.notes
end

---@return number
---@return number
function EditorViewContext:getIterRange()
	return self.model:getIterRange()
end

---@return rizu.editor.EditorNoteContext
function EditorViewContext:getEditorNoteContext()
	return self.model.context:getNoteEditContext()
end

function EditorViewContext:resetVisual()
	self.model.visualEngine:reset()
end

---@param point chartedit.Point
function EditorViewContext:scrollPoint(point)
	self.model:scrollPoint(point)
end

---@param point chartedit.Point
function EditorViewContext:scrollTimePoint(point)
	self.model.scroller:scrollTimePoint(point)
end

---@return rizu.editor.BmsToolsContext
function EditorViewContext:getBmsToolsContext()
	return self.model.bmsToolsContext
end

---@return chartedit.Layer
function EditorViewContext:getLayer()
	return self.model.layer
end

---@return rizu.editor.EditorAnalysisService
function EditorViewContext:getAnalysisService()
	return self.model.analysisService
end

---@return rizu.editor.EditorAnalysisContext
function EditorViewContext:getAnalysisContext()
	return self.model.context:getAnalysisContext()
end

---@return rizu.editor.NcbtContext
function EditorViewContext:getNcbtContext()
	return self.model.ncbtContext
end

---@return number
---@return number
function EditorViewContext:getTimelineRange()
	return self.model.analysisService:getTimelineRange(self.model.context:getAnalysisContext())
end

---@return table
function EditorViewContext:getDensityGraph()
	return self.model.graphsGenerator.densityGraph
end

---@return table
function EditorViewContext:getVertexDataGraph()
	return self.model.graphsGenerator.vertexDatasGraph
end

---@return number?
function EditorViewContext:getPreviewTime()
	return self.model:getPreviewTime()
end

---@param time number
function EditorViewContext:scrollSeconds(time)
	self.model.scroller:scrollSeconds(time)
end

---@return boolean
function EditorViewContext:isFineScrollRequested()
	return self.model.isFineScrollRequested()
end

---@return boolean
function EditorViewContext:isSnapChangeRequested()
	return self.model.isSnapChangeRequested()
end

---@return boolean
function EditorViewContext:isSpeedChangeRequested()
	return self.model.isSpeedChangeRequested()
end

---@return number
function EditorViewContext:getLogSpeed()
	return self.model:getLogSpeed()
end

---@param logSpeed number
function EditorViewContext:setLogSpeed(logSpeed)
	self.model:setLogSpeed(logSpeed)
end

---@param delta number
function EditorViewContext:scrollSecondsDelta(delta)
	self.model.scroller:scrollSecondsDelta(delta)
end

---@param scroll number
function EditorViewContext:scrollSnaps(scroll)
	self.model.scroller:scrollSnaps(scroll)
end

function EditorViewContext:incSnap()
	self.model:incSnap()
end

function EditorViewContext:decSnap()
	self.model:decSnap()
end

---@return boolean
function EditorViewContext:isPlaying()
	return self.model.timer.is_playing
end

---@return number
function EditorViewContext:getRate()
	return self.model.timer.rate
end

---@param rate number
function EditorViewContext:setRate(rate)
	self.model.timer:setRate(rate)
	self.model.audio_engine:setRate(rate)
end

function EditorViewContext:play()
	self.model:play()
end

function EditorViewContext:pause()
	self.model:pause()
end

---@param owner string?
---@return boolean
function EditorViewContext:isDragging(owner)
	return self.model.viewState:isDragging(owner)
end

---@param dragging boolean
---@param owner string?
function EditorViewContext:setDragging(dragging, owner)
	self.model.viewState:setDragging(dragging, owner)
end

return EditorViewContext
