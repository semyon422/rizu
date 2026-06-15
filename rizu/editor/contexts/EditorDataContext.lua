local class = require("class")

---@class rizu.editor.EditorDataContext: rizu.editor.EditorLoadContext, rizu.editor.EditorSaveContext, rizu.editor.EditorSessionResetContext, rizu.editor.EditorResourceLoadContext, rizu.editor.EditorAnalysisContext, rizu.editor.NoteChartLoaderContext, rizu.editor.IntervalManagerContext
---@operator call: rizu.editor.EditorDataContext
---@field model rizu.editor.EditorModel
local EditorDataContext = class()

---@param model rizu.editor.EditorModel
function EditorDataContext:new(model)
	self.model = model
end

---@return chart.sph.Metadata
function EditorDataContext:getMetadata()
	return self.model.metadata
end

---@param chartmeta table
function EditorDataContext:setChartmeta(chartmeta)
	self.model.chartmeta = chartmeta
end

---@return rizu.editor.NoteChartLoader
function EditorDataContext:getNoteChartLoader()
	return self.model.noteChartLoader
end

---@param loaded boolean
function EditorDataContext:setLoaded(loaded)
	self.model:setLoaded(loaded)
end

---@return table
function EditorDataContext:getSettings()
	return self.model:getSettings()
end

---@param layer chartedit.Layer
---@param notes chartedit.Notes
function EditorDataContext:setChartData(layer, notes)
	self.model.layer = layer
	self.model.notes = notes
end

---@param visual chartedit.Visual?
function EditorDataContext:setVisual(visual)
	self.model:setVisual(visual)
end

---@return rizu.editor.EditorSessionResetService
function EditorDataContext:getSessionResetService()
	return self.model.sessionResetService
end

---@return rizu.editor.EditorSessionResetContext
function EditorDataContext:getSessionResetContext()
	return self
end

---@param changes Changes
function EditorDataContext:setChanges(changes)
	self.model:setChanges(changes)
end

---@param loaded boolean
function EditorDataContext:setResourcesLoaded(loaded)
	self.model:setResourcesLoaded(loaded)
end

---@param time number
function EditorDataContext:setSessionTime(time)
	self.model:setSessionTime(time)
end

---@return rizu.editor.EditorAnalysisState
function EditorDataContext:getAnalysisState()
	return self.model:getAnalysisState()
end

---@return rizu.editor.EditorSelectionState
function EditorDataContext:getSelectionState()
	return self.model:getSelectionState()
end

---@return rizu.editor.EditorPlaybackService
function EditorDataContext:getPlaybackService()
	return self.model.playbackService
end

---@return rizu.editor.EditorPlaybackContext
function EditorDataContext:getPlaybackContext()
	return self.model.context:getPlaybackContext()
end

---@return rizu.editor.EditorAnalysisService
function EditorDataContext:getAnalysisService()
	return self.model.analysisService
end

---@return rizu.editor.EditorAnalysisContext
function EditorDataContext:getAnalysisContext()
	return self
end

---@return rizu.editor.TimeManager
function EditorDataContext:getTimer()
	return self.model.timer
end

---@return rizu.engine.audio.Engine
function EditorDataContext:getAudioEngine()
	return self.model.audio_engine
end

---@return table
function EditorDataContext:getAudioSettings()
	return self.model:getAudioSettings()
end

---@return sphere.ConfigModel
function EditorDataContext:getConfigModel()
	return self.model.configModel
end

---@return rizu.editor.Metronome
function EditorDataContext:getMetronome()
	return self.model.metronome
end

---@return rizu.editor.Scroller
function EditorDataContext:getScroller()
	return self.model.scroller
end

---@return rizu.editor.BmsToolsContext
function EditorDataContext:getBmsToolsContext()
	return self.model.bmsToolsContext
end

---@return table
function EditorDataContext:getChartmeta()
	return self.model.chartmeta
end

---@return chart.Chart
function EditorDataContext:getChart()
	return self.model.chart
end

---@return chartedit.Layer
function EditorDataContext:getLayer()
	return self.model.layer
end

---@return chartedit.Notes
function EditorDataContext:getNotes()
	return self.model.notes
end

---@return rizu.editor.IntervalManager
function EditorDataContext:getIntervalManager()
	return self.model.intervalManager
end

---@return rizu.editor.GraphsGenerator
function EditorDataContext:getGraphsGenerator()
	return self.model.graphsGenerator
end

---@return rizu.editor.NcbtContext
function EditorDataContext:getNcbtContext()
	return self.model.ncbtContext
end

---@param wave table?
function EditorDataContext:setWave(wave)
	self.model:setWave(wave)
end

---@return table?
function EditorDataContext:getWave()
	return self.model:getWave()
end

---@return rizu.editor.EditorChanges
function EditorDataContext:getEditorChanges()
	return self.model.editorChanges
end

return EditorDataContext
