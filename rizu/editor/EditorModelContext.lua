local class = require("class")
local EditorSessionResetService = require("rizu.editor.EditorSessionResetService")

---@class rizu.editor.EditorModelContext: rizu.editor.EditorLoadContext, rizu.editor.EditorSaveContext, rizu.editor.EditorSessionResetContext, rizu.editor.EditorResourceLoadContext, rizu.editor.EditorPlaybackContext, rizu.editor.EditorSettingsContext, rizu.editor.EditorAnalysisContext, rizu.editor.EditorSelectionRectContext, rizu.editor.EditorModelFrameContext, rizu.editor.EditorNoteServiceContext, rizu.editor.VisualEngineContext, rizu.editor.NoteChartLoaderContext, rizu.editor.IntervalManagerContext, rizu.editor.EditorChangesContext, rizu.editor.ScrollerContext, rizu.editor.MetronomeContext, rizu.editor.EditorNoteOpsContext, rizu.editor.EditorNoteContext
---@operator call: rizu.editor.EditorModelContext
---@field model rizu.editor.EditorModel
local EditorModelContext = class()

---@param model rizu.editor.EditorModel
function EditorModelContext:new(model)
	self.model = model
end

-- Load/save context

---@return chart.sph.Metadata
function EditorModelContext:getMetadata()
	return self.model.metadata
end

---@param chartmeta table
function EditorModelContext:setChartmeta(chartmeta)
	self.model.chartmeta = chartmeta
end

---@return rizu.editor.NoteChartLoader
function EditorModelContext:getNoteChartLoader()
	return self.model.noteChartLoader
end

---@param loaded boolean
function EditorModelContext:setLoaded(loaded)
	self.model:setLoaded(loaded)
end

---@return table
function EditorModelContext:getSettings()
	return self.model:getSettings()
end

---@param layer chartedit.Layer
---@param notes chartedit.Notes
function EditorModelContext:setChartData(layer, notes)
	self.model.layer = layer
	self.model.notes = notes
end

---@param visual chartedit.Visual?
function EditorModelContext:setVisual(visual)
	self.model:setVisual(visual)
end

-- Load-time session reset context

---@return rizu.editor.EditorSessionResetService
function EditorModelContext:getSessionResetService()
	return self.model.sessionResetService
end

---@return rizu.editor.EditorSessionResetContext
function EditorModelContext:getSessionResetContext()
	return self
end

function EditorModelContext:analyzePatterns()
	self.model:analyzePatterns()
end

---@return Changes
function EditorModelContext:newChanges()
	local sessionResetService = self.model.sessionResetService
	local newChanges = sessionResetService.newChanges or EditorSessionResetService.newChanges
	return newChanges()
end

---@param changes Changes
function EditorModelContext:setChanges(changes)
	self.model:setChanges(changes)
end

function EditorModelContext:loadGraphs()
	self.model.graphsGenerator:load()
end

---@param loaded boolean
function EditorModelContext:setResourcesLoaded(loaded)
	self.model:setResourcesLoaded(loaded)
end

---@param time number
function EditorModelContext:setSessionTime(time)
	self.model:setSessionTime(time)
end

function EditorModelContext:finishSelection()
	self.model:getSelectionState():finish()
end

-- Playback and resource-load context

---@return rizu.editor.EditorPlaybackService?
function EditorModelContext:getPlaybackService()
	return self.model.playbackService
end

---@return rizu.editor.TimeManager
function EditorModelContext:getTimer()
	return self.model.timer
end

---@return rizu.engine.audio.Engine
function EditorModelContext:getAudioEngine()
	return self.model.audio_engine
end

---@return table
function EditorModelContext:getAudioSettings()
	return self.model:getAudioSettings()
end

---@return sphere.ConfigModel
function EditorModelContext:getConfigModel()
	return self.model.configModel
end

---@return rizu.editor.Metronome
function EditorModelContext:getMetronome()
	return self.model.metronome
end

---@return rizu.editor.Scroller
function EditorModelContext:getScroller()
	return self.model.scroller
end

---@return rizu.editor.BmsToolsContext
function EditorModelContext:getBmsToolsContext()
	return self.model.bmsToolsContext
end

---@param loadedResources {[string]: string}
function EditorModelContext:loadAudioResources(loadedResources)
	self.model.playbackService:loadEditorAudioResources(self, loadedResources)
end

function EditorModelContext:renderWave()
	self.model:renderWave()
end

function EditorModelContext:genGraphs()
	self.model:genGraphs()
end

-- Chart data and analysis context

---@return table
function EditorModelContext:getChartmeta()
	return self.model.chartmeta
end

---@return chart.Chart
function EditorModelContext:getChart()
	return self.model.chart
end

---@return chartedit.Layer
function EditorModelContext:getLayer()
	return self.model.layer
end

---@return chartedit.Notes
function EditorModelContext:getNotes()
	return self.model.notes
end

---@return rizu.editor.IntervalManager
function EditorModelContext:getIntervalManager()
	return self.model.intervalManager
end

---@return rizu.editor.GraphsGenerator
function EditorModelContext:getGraphsGenerator()
	return self.model.graphsGenerator
end

---@return rizu.editor.NcbtContext
function EditorModelContext:getNcbtContext()
	return self.model.ncbtContext
end

---@param wave table?
function EditorModelContext:setWave(wave)
	self.model:setWave(wave)
end

---@return rizu.editor.EditorChanges
function EditorModelContext:getEditorChanges()
	return self.model.editorChanges
end

-- Selection context

---@return rizu.editor.EditorSelectionState
function EditorModelContext:getSelectionState()
	return self.model:getSelectionState()
end

---@return number
---@return number
function EditorModelContext:getMousePosition()
	return self.model.getMousePosition()
end

---@return number
function EditorModelContext:getMouseTime()
	return self.model:getMouseTime()
end

---@param x1 number
---@param y1 number
---@param x2 number
---@param y2 number
function EditorModelContext:selectRegion(x1, y1, x2, y2)
	self.model.selectRegion(x1, y1, x2, y2)
end

function EditorModelContext:unselectRegion()
	self.model.unselectRegion()
end

-- Timeline and scrolling context

---@param absoluteTime number
---@return chartedit.Point?
function EditorModelContext:getDtpAbsolute(absoluteTime)
	return self.model:getDtpAbsolute(absoluteTime)
end

---@return number
function EditorModelContext:getSessionTime()
	return self.model:getSessionTime()
end

---@return chartedit.Point
function EditorModelContext:getPoint()
	return self.model:getPoint()
end

---@param point chartedit.Point
function EditorModelContext:setSessionPoint(point)
	self.model:setSessionPoint(point)
end

---@param time number
function EditorModelContext:setTime(time)
	self.model:setTime(time)
end

---@return boolean
function EditorModelContext:isIntervalGrabbed()
	return self.model.intervalManager:isGrabbed()
end

---@param vertex chartedit.Vertex
---@param time chart.Fraction
---@return chartedit.Point
function EditorModelContext:interpolateFraction(vertex, time)
	return self.model.layer.points:interpolateFraction(vertex, time)
end

function EditorModelContext:resetVisual()
	self.model.visualEngine:reset()
end

-- Visual/note rendering context

---@return table
function EditorModelContext:getEditorSettings()
	return self.model.configModel.configs.settings.editor
end

---@return chartedit.Point?
function EditorModelContext:getVisualPoint()
	return self.model.visualPoint
end

---@return chartedit.Visual?
function EditorModelContext:getVisual()
	return self.model:getVisual()
end

---@return number
---@return number
function EditorModelContext:getIterRange()
	return self.model:getIterRange()
end

---@return rizu.editor.EditorModelContext
function EditorModelContext:getEditorNoteContext()
	return self
end

---@param point chartedit.Point
---@param delta number
---@return chartedit.Vertex
---@return chart.Fraction
function EditorModelContext:getNextSnapIntervalTime(point, delta)
	return self.model.scroller:getNextSnapIntervalTime(point, delta)
end

---@return number
function EditorModelContext:getCurrentTime()
	return self.model.timer:getTime()
end

---@return table?
function EditorModelContext:getNoteSkin()
	return self.model:getNoteSkin()
end

-- Frame/update service context

---@return rizu.editor.EditorServices?
function EditorModelContext:getServices()
	return self.model.services
end

---@return rizu.editor.EditorNoteService
function EditorModelContext:getNoteService()
	return self.model.noteService
end

---@return rizu.editor.EditorSelectionService?
function EditorModelContext:getSelectionService()
	return self.model.selectionService
end

---@return rizu.editor.VisualEngine
function EditorModelContext:getVisualEngine()
	return self.model.visualEngine
end

---@return integer
function EditorModelContext:getMaxSnap()
	return self.model.max_snap
end

-- Note editing context

---@return {[chart.Note]: rizu.editor.EditorNote}
function EditorModelContext:getSelectedNotes()
	return self.model.visualEngine.selectedNotes
end

---@return rizu.editor.EditorNoteOpsContext
function EditorModelContext:getNoteOpsContext()
	return self
end

---@return rizu.VisualInfo
function EditorModelContext:getVisualInfo()
	return self.model.visualEngine.visual_info
end

---@param note rizu.editor.EditorNote?
function EditorModelContext:selectNote(note)
	self.model.visualEngine:selectNote(note)
end

return EditorModelContext
