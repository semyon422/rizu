local EditorServices = require("rizu.editor.EditorServices")

local test = {}
local createDeps

---@param t testing.T
function test.applies_and_attaches_editor_model_collaborators(t)
	local deps = createDeps()
	local services = EditorServices(deps)
	local editorModel = {}

	services:applyToEditorModel(editorModel)
	services:attachEditorModel(editorModel)

	t:eq(editorModel.noteChartLoader, deps.noteChartLoader)
	t:eq(editorModel.audio_engine, deps.audio_engine)
	t:eq(editorModel.ncbtContext, deps.ncbtContext)
	t:eq(editorModel.intervalManager, deps.intervalManager)
	t:eq(editorModel.graphsGenerator, deps.graphsGenerator)
	t:eq(editorModel.editorChanges, deps.editorChanges)
	t:eq(editorModel.timer, deps.timer)
	t:eq(editorModel.noteService, deps.noteService)
	t:eq(editorModel.visualEngine, deps.visualEngine)
	t:eq(editorModel.scroller, deps.scroller)
	t:eq(editorModel.metronome, deps.metronome)
	t:eq(editorModel.metadata, deps.metadata)
	t:eq(editorModel.bmsToolsContext, deps.bmsToolsContext)
	t:eq(editorModel.loadService, deps.loadService)
	t:eq(editorModel.sessionResetService, deps.sessionResetService)
	t:eq(editorModel.resourceLoadService, deps.resourceLoadService)
	t:eq(editorModel.playbackService, deps.playbackService)
	t:eq(editorModel.selectionService, deps.selectionService)
	t:eq(editorModel.settingsService, deps.settingsService)
	t:eq(editorModel.cursorState, deps.cursorState)
	t:eq(editorModel.selectionState, deps.selectionState)
	t:eq(editorModel.renderState, deps.renderState)
	t:eq(editorModel.analysisState, deps.analysisState)
	t:eq(editorModel.runtimeState, deps.runtimeState)
	t:eq(editorModel.viewState, deps.viewState)
	t:eq(deps.noteChartLoader.editorModel, editorModel)
	t:eq(deps.ncbtContext.editorModel, editorModel)
	t:eq(deps.intervalManager.editorModel, editorModel)
	t:eq(deps.graphsGenerator.editorModel, editorModel)
	t:eq(deps.editorChanges.editorModel, editorModel)
	t:eq(deps.noteService.editorModel, editorModel)
	t:eq(deps.noteService.attachedWithMethod, true)
	t:eq(deps.visualEngine.editorModel, editorModel)
	t:eq(deps.scroller.editorModel, editorModel)
	t:eq(deps.metronome.editorModel, editorModel)
	t:eq(deps.bmsToolsContext.editorModel, editorModel)
	t:eq(deps.audio_engine.editorModel, nil)
	t:eq(deps.timer.editorModel, nil)
	t:eq(deps.metadata.editorModel, nil)
	t:eq(deps.loadService.editorModel, nil)
	t:eq(deps.sessionResetService.editorModel, nil)
	t:eq(deps.resourceLoadService.editorModel, nil)
	t:eq(deps.playbackService.editorModel, nil)
	t:eq(deps.selectionService.editorModel, nil)
	t:eq(deps.settingsService.editorModel, nil)
	t:eq(deps.cursorState.editorModel, nil)
	t:eq(deps.selectionState.editorModel, nil)
	t:eq(deps.renderState.editorModel, nil)
	t:eq(deps.analysisState.editorModel, nil)
	t:eq(deps.runtimeState.editorModel, nil)
	t:eq(deps.viewState.editorModel, nil)
end

---@param t testing.T
function test.update_ticks_frame_services(t)
	local calls = {}
	local deps = createDeps()
	deps.noteService.update = function()
		table.insert(calls, "notes")
	end
	deps.metronome.update = function()
		table.insert(calls, "metronome")
	end
	local services = EditorServices(deps)

	services:update()

	t:tdeq(calls, {"notes", "metronome"})
end

---@return rizu.editor.EditorServicesDeps
function createDeps()
	local noteService = {
		setEditorModel = function(self, editorModel)
			self.editorModel = editorModel
			self.attachedWithMethod = true
		end,
	}
	return {
		noteChartLoader = {},
		audio_engine = {},
		ncbtContext = {},
		intervalManager = {},
		graphsGenerator = {},
		editorChanges = {},
		timer = {},
		noteService = noteService,
		visualEngine = {},
		scroller = {},
		metronome = {},
		metadata = {},
		bmsToolsContext = {},
		loadService = {},
		sessionResetService = {},
		resourceLoadService = {},
		playbackService = {},
		selectionService = {},
		settingsService = {},
		cursorState = {},
		selectionState = {},
		renderState = {},
		analysisState = {},
		runtimeState = {},
		viewState = {},
	}
end

return test
