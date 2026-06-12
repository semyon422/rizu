local class = require("class")
local AudioEngine = require("rizu.engine.audio.Engine")
local TimeManager = require("rizu.editor.TimeManager")
local VisualEngine = require("rizu.editor.VisualEngine")
local NoteChartLoader = require("rizu.editor.NoteChartLoader")
local NcbtContext = require("rizu.editor.NcbtContext")
local IntervalManager = require("rizu.editor.IntervalManager")
local GraphsGenerator = require("rizu.editor.GraphsGenerator")
local EditorChanges = require("rizu.editor.EditorChanges")
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

---@class rizu.editor.EditorServicesDeps
---@field fs fs.IFilesystem?
---@field noteChartLoader rizu.editor.NoteChartLoader?
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

---@class rizu.editor.EditorServices
---@operator call: rizu.editor.EditorServices
---@field noteChartLoader rizu.editor.NoteChartLoader
---@field audio_engine rizu.engine.audio.Engine
---@field ncbtContext rizu.editor.NcbtContext
---@field intervalManager rizu.editor.IntervalManager
---@field graphsGenerator rizu.editor.GraphsGenerator
---@field editorChanges rizu.editor.EditorChanges
---@field timer rizu.editor.TimeManager
---@field noteService rizu.editor.EditorNoteService
---@field visualEngine rizu.editor.VisualEngine
---@field scroller rizu.editor.Scroller
---@field metronome rizu.editor.Metronome
---@field metadata chart.sph.Metadata
---@field bmsToolsContext rizu.editor.BmsToolsContext
---@field loadService rizu.editor.EditorLoadService
---@field sessionResetService rizu.editor.EditorSessionResetService
---@field resourceLoadService rizu.editor.EditorResourceLoadService
---@field playbackService rizu.editor.EditorPlaybackService
---@field selectionService rizu.editor.EditorSelectionService
---@field settingsService rizu.editor.EditorSettingsService
---@field cursorState rizu.editor.EditorCursorState
---@field selectionState rizu.editor.EditorSelectionState
---@field renderState rizu.editor.EditorRenderState
---@field analysisState rizu.editor.EditorAnalysisState
---@field runtimeState rizu.editor.EditorRuntimeState
---@field viewState rizu.editor.EditorViewState
local EditorServices = class()

---@param deps rizu.editor.EditorServicesDeps?
function EditorServices:new(deps)
	deps = deps or {}
	self.noteChartLoader = deps.noteChartLoader or NoteChartLoader()
	self.audio_engine = deps.audio_engine or AudioEngine()
	self.ncbtContext = deps.ncbtContext or NcbtContext()
	self.intervalManager = deps.intervalManager or IntervalManager()
	self.graphsGenerator = deps.graphsGenerator or GraphsGenerator()
	self.editorChanges = deps.editorChanges or EditorChanges()
	self.timer = deps.timer or TimeManager()
	self.noteService = deps.noteService or EditorNoteService()
	self.visualEngine = deps.visualEngine or VisualEngine()
	self.scroller = deps.scroller or Scroller()
	self.metronome = deps.metronome or Metronome(deps.fs)
	self.metadata = deps.metadata or Metadata()
	self.bmsToolsContext = deps.bmsToolsContext or BmsToolsContext()
	self.loadService = deps.loadService or EditorLoadService()
	self.sessionResetService = deps.sessionResetService or EditorSessionResetService()
	self.resourceLoadService = deps.resourceLoadService or EditorResourceLoadService()
	self.playbackService = deps.playbackService or EditorPlaybackService()
	self.selectionService = deps.selectionService or EditorSelectionService()
	self.settingsService = deps.settingsService or EditorSettingsService()
	self.cursorState = deps.cursorState or EditorCursorState()
	self.selectionState = deps.selectionState or EditorSelectionState()
	self.renderState = deps.renderState or EditorRenderState()
	self.analysisState = deps.analysisState or EditorAnalysisState()
	self.runtimeState = deps.runtimeState or EditorRuntimeState()
	self.viewState = deps.viewState or EditorViewState()
end

---@param editorModel rizu.editor.EditorModel
function EditorServices:applyToEditorModel(editorModel)
	editorModel.noteChartLoader = self.noteChartLoader
	editorModel.audio_engine = self.audio_engine
	editorModel.ncbtContext = self.ncbtContext
	editorModel.intervalManager = self.intervalManager
	editorModel.graphsGenerator = self.graphsGenerator
	editorModel.editorChanges = self.editorChanges
	editorModel.timer = self.timer
	editorModel.noteService = self.noteService
	editorModel.visualEngine = self.visualEngine
	editorModel.scroller = self.scroller
	editorModel.metronome = self.metronome
	editorModel.metadata = self.metadata
	editorModel.bmsToolsContext = self.bmsToolsContext
	editorModel.loadService = self.loadService
	editorModel.sessionResetService = self.sessionResetService
	editorModel.resourceLoadService = self.resourceLoadService
	editorModel.playbackService = self.playbackService
	editorModel.selectionService = self.selectionService
	editorModel.settingsService = self.settingsService
	editorModel.cursorState = self.cursorState
	editorModel.selectionState = self.selectionState
	editorModel.renderState = self.renderState
	editorModel.analysisState = self.analysisState
	editorModel.runtimeState = self.runtimeState
	editorModel.viewState = self.viewState
end

---@param editorModel rizu.editor.EditorModel
function EditorServices:attachEditorModel(editorModel)
	self.noteChartLoader:setContext(editorModel:createNoteChartLoaderContext())
	self.intervalManager:setContext(editorModel:createIntervalManagerContext())
	self.editorChanges:setContext(editorModel:createEditorChangesContext())
	self.noteService:setContext(editorModel:createEditorNoteServiceContext())
	self.visualEngine:setContext(editorModel:createVisualEngineContext())
	self.scroller:setContext(editorModel:createScrollerContext())
	self.metronome:setContext(editorModel:createMetronomeContext())
end

function EditorServices:update()
	self.noteService:update()
	self.metronome:update()
end

return EditorServices
