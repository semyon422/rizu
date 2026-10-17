local EditorOverlayActionService = require("rizu.editor.view.overlays.EditorOverlayActionService")

local test = {}

local function createContext(fields)
	return {
		getChartmeta = function()
			return fields.chartmeta
		end,
		getSessionTime = function()
			return fields.sessionTime
		end,
		getNoteService = function()
			return fields.noteService
		end,
		getSelectedNotes = function()
			return fields.selectedNotes
		end,
		scrollPoint = function(_, point)
			return fields.scrollPoint(point)
		end,
		getBmsToolsContext = function()
			return fields.bmsToolsContext
		end,
		getLayer = function()
			return fields.layer
		end,
		getAnalysisService = function()
			return fields.analysisService
		end,
		getAnalysisContext = function()
			return fields.analysisContext
		end,
		getNcbtContext = function()
			return fields.ncbtContext
		end,
	}
end

---@param t testing.T
function test.ui_action_methods_update_editor_state(t)
	local calls = {}
	local point = {}
	local selectedVisualPoint = {}
	local selectedNote = {
		startNote = {
			visualPoint = selectedVisualPoint,
		},
	}
	local chartmeta = {}
	local context = createContext({
		chartmeta = chartmeta,
		sessionTime = 12.5,
		selectedNotes = {
			[selectedNote.startNote] = selectedNote,
		},
		noteService = {
			changeType = function()
				table.insert(calls, "change-type")
			end,
		},
		scrollPoint = function(scrolledPoint)
			table.insert(calls, "scroll")
			t:eq(scrolledPoint, point)
		end,
	})
	selectedVisualPoint.point = point

	local service = EditorOverlayActionService()
	service:setPreviewTimeToSession(context)
	service:changeSelectedNoteType(context)
	local scrolled = service:scrollToFirstSelectedNote(context)
	service:setVisualPointComment(selectedVisualPoint, "")
	service:setVisualPointComment(selectedVisualPoint, "comment")
	service:resetVisualPointComment(selectedVisualPoint)
	service:setSelectedNotesComment(context, "batch")
	service:resetSelectedNotesComment(context)

	t:eq(chartmeta.preview_time, 12.5)
	t:eq(scrolled, true)
	t:eq(selectedVisualPoint.comment, nil)
	t:eq(selectedVisualPoint.temp_comment, nil)
	t:tdeq(calls, {"change-type", "scroll"})
end

---@param t testing.T
function test.scroll_to_first_selected_note_returns_false_without_selection(t)
	local context = createContext({
		selectedNotes = {},
		scrollPoint = function()
			error("unexpected scroll")
		end,
	})

	t:eq(EditorOverlayActionService():scrollToFirstSelectedNote(context), false)
end

---@param t testing.T
function test.selected_notes_action_input_runs_only_when_selection_exists(t)
	local calls = {}
	local point = {}
	local visualPoint = {
		point = point,
	}
	local selectedNote = {
		startNote = {
			visualPoint = visualPoint,
		},
	}
	local service = EditorOverlayActionService()
	local context = createContext({
		selectedNotes = {
			[selectedNote.startNote] = selectedNote,
		},
		noteService = {
			changeType = function()
				table.insert(calls, "change-type")
			end,
		},
		scrollPoint = function(scrolledPoint)
			table.insert(calls, "scroll")
			t:eq(scrolledPoint, point)
		end,
	})
	local state = service:getSelectedNotesActionState(context)

	t:eq(state.hasSelectedNotes, true)

	service:handleSelectedNotesActionInput(context, state, {
		changeTypePressed = true,
		scrollPressed = true,
		saveCommentPressed = true,
		resetCommentPressed = false,
		comment = "comment",
	})

	t:eq(visualPoint.comment, "comment")
	t:tdeq(calls, {"change-type", "scroll"})
end

---@param t testing.T
function test.selected_notes_action_input_ignores_commands_without_selection(t)
	local calls = {}
	local service = EditorOverlayActionService()
	local context = createContext({
		selectedNotes = {},
		noteService = {
			changeType = function()
				table.insert(calls, "change-type")
			end,
		},
		scrollPoint = function()
			table.insert(calls, "scroll")
		end,
	})
	local state = service:getSelectedNotesActionState(context)

	t:eq(state.hasSelectedNotes, false)

	service:handleSelectedNotesActionInput(context, state, {
		changeTypePressed = true,
		scrollPressed = true,
		saveCommentPressed = true,
		resetCommentPressed = true,
		comment = "comment",
	})

	t:tdeq(calls, {})
end

---@param t testing.T
function test.bms_ui_methods_apply_offset_tempo(t)
	local calls = {}
	local layer = {}
	local bmsToolsContext = {
		offset = 0.25,
		resetOffsetTempo = function(_, appliedLayer)
			table.insert(calls, "reset")
			t:eq(appliedLayer, layer)
		end,
	}
	local context = createContext({
		layer = layer,
		bmsToolsContext = bmsToolsContext,
	})

	local service = EditorOverlayActionService()
	service:applyBmsOffsetTempo(context)
	service:changeBmsOffset(context, 0.001)

	t:eq(bmsToolsContext.offset, 0.251)
	t:tdeq(calls, {"reset", "reset"})
end

---@param t testing.T
function test.analysis_ui_methods_delegate_to_analysis_service(t)
	local calls = {}
	local analysisContext = {}
	local context = createContext({
		analysisContext = analysisContext,
		ncbtContext = {
			tempo = 120,
		},
		analysisService = {
			detectTempoOffset = function(_, contextArg)
				table.insert(calls, "detect")
				t:eq(contextArg, analysisContext)
			end,
			applyNcbt = function(_, contextArg)
				table.insert(calls, "apply")
				t:eq(contextArg, analysisContext)
			end,
			getTotalBeats = function(_, contextArg)
				table.insert(calls, "beats")
				t:eq(contextArg, analysisContext)
				return 12, 0.5
			end,
		},
	})
	local service = EditorOverlayActionService()

	service:detectTempoOffset(context)
	t:eq(service:hasDetectedTempoOffset(context), true)
	local ncbtActionState = service:getNcbtActionState(context)
	t:eq(ncbtActionState.canApply, true)
	service:handleNcbtActionInput(context, ncbtActionState, {
		detectPressed = true,
		applyPressed = true,
	})
	service:applyNcbt(context)
	local totalBeats, avgBeatDuration = service:getTotalBeats(context)
	local beatSummaryState = service:getBeatSummaryState(context)

	t:eq(totalBeats, 12)
	t:eq(avgBeatDuration, 0.5)
	t:eq(beatSummaryState.totalBeats, 12)
	t:eq(beatSummaryState.avgBeatDuration, 0.5)
	t:eq(beatSummaryState.totalBeatsLabel, "Total beats: 12")
	t:eq(beatSummaryState.averageTempoLabel, "Average tempo: 120 bpm")
	t:tdeq(calls, {"detect", "detect", "apply", "apply", "beats", "beats"})
end

---@param t testing.T
function test.ncbt_action_input_does_not_apply_when_unavailable(t)
	local calls = {}
	local service = EditorOverlayActionService()
	local context = createContext({
		analysisContext = {},
		ncbtContext = {},
		analysisService = {
			detectTempoOffset = function()
				table.insert(calls, "detect")
			end,
			applyNcbt = function()
				table.insert(calls, "apply")
			end,
		},
	})
	local state = service:getNcbtActionState(context)

	service:handleNcbtActionInput(context, state, {
		detectPressed = true,
		applyPressed = true,
	})

	t:eq(state.canApply, false)
	t:tdeq(calls, {"detect"})
end

return test
