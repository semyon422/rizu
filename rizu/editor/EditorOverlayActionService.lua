local class = require("class")

---@class rizu.editor.EditorBeatSummaryState
---@field totalBeats number
---@field avgBeatDuration number
---@field totalBeatsLabel string
---@field averageTempoLabel string

---@class rizu.editor.EditorNcbtActionState
---@field canApply boolean

---@class rizu.editor.EditorNcbtActionInput
---@field detectPressed boolean
---@field applyPressed boolean

---@class rizu.editor.EditorOverlayActionContext
---@field getChartmeta fun(self: rizu.editor.EditorOverlayActionContext): table
---@field getSessionTime fun(self: rizu.editor.EditorOverlayActionContext): number
---@field getNoteService fun(self: rizu.editor.EditorOverlayActionContext): rizu.editor.EditorNoteService
---@field getSelectedNotes fun(self: rizu.editor.EditorOverlayActionContext): {[chart.Note]: rizu.editor.EditorNote}
---@field scrollPoint fun(self: rizu.editor.EditorOverlayActionContext, point: chartedit.Point)
---@field getBmsToolsContext fun(self: rizu.editor.EditorOverlayActionContext): rizu.editor.BmsToolsContext
---@field getLayer fun(self: rizu.editor.EditorOverlayActionContext): chartedit.Layer
---@field getAnalysisService fun(self: rizu.editor.EditorOverlayActionContext): rizu.editor.EditorAnalysisService
---@field getAnalysisContext fun(self: rizu.editor.EditorOverlayActionContext): rizu.editor.EditorAnalysisContext
---@field getNcbtContext fun(self: rizu.editor.EditorOverlayActionContext): rizu.editor.NcbtContext

---@class rizu.editor.EditorOverlayActionService
---@operator call: rizu.editor.EditorOverlayActionService
local EditorOverlayActionService = class()

---@param context rizu.editor.EditorOverlayActionContext
function EditorOverlayActionService:setPreviewTimeToSession(context)
	context:getChartmeta().preview_time = context:getSessionTime()
end

---@param context rizu.editor.EditorOverlayActionContext
function EditorOverlayActionService:changeSelectedNoteType(context)
	context:getNoteService():changeType()
end

---@param context rizu.editor.EditorOverlayActionContext
---@return boolean
function EditorOverlayActionService:scrollToFirstSelectedNote(context)
	local _, note = next(context:getSelectedNotes())
	if not note then
		return false
	end
	context:scrollPoint(note.startNote.visualPoint.point)
	return true
end

---@param visualPoint chartedit.VisualPoint
---@param comment string?
function EditorOverlayActionService:setVisualPointComment(visualPoint, comment)
	if comment == "" then
		comment = nil
	end
	visualPoint.comment = comment
end

---@param visualPoint chartedit.VisualPoint
function EditorOverlayActionService:resetVisualPointComment(visualPoint)
	visualPoint.comment = nil
	visualPoint.temp_comment = nil
end

---@param context rizu.editor.EditorOverlayActionContext
---@param comment string?
function EditorOverlayActionService:setSelectedNotesComment(context, comment)
	if comment == "" then
		comment = nil
	end
	for _, note in pairs(context:getSelectedNotes()) do
		note.startNote.visualPoint.comment = comment
	end
end

---@param context rizu.editor.EditorOverlayActionContext
function EditorOverlayActionService:resetSelectedNotesComment(context)
	for _, note in pairs(context:getSelectedNotes()) do
		note.startNote.visualPoint.comment = nil
	end
end

---@param context rizu.editor.EditorOverlayActionContext
function EditorOverlayActionService:applyBmsOffsetTempo(context)
	context:getBmsToolsContext():resetOffsetTempo(context:getLayer())
end

---@param context rizu.editor.EditorOverlayActionContext
---@param delta number
function EditorOverlayActionService:changeBmsOffset(context, delta)
	local bmsToolsContext = context:getBmsToolsContext()
	bmsToolsContext.offset = bmsToolsContext.offset + delta
	self:applyBmsOffsetTempo(context)
end

---@param context rizu.editor.EditorOverlayActionContext
function EditorOverlayActionService:detectTempoOffset(context)
	context:getAnalysisService():detectTempoOffset(context:getAnalysisContext())
end

---@param context rizu.editor.EditorOverlayActionContext
---@return boolean
function EditorOverlayActionService:hasDetectedTempoOffset(context)
	return context:getNcbtContext().tempo ~= nil
end

---@param context rizu.editor.EditorOverlayActionContext
---@return rizu.editor.EditorNcbtActionState
function EditorOverlayActionService:getNcbtActionState(context)
	return {
		canApply = self:hasDetectedTempoOffset(context),
	}
end

---@param context rizu.editor.EditorOverlayActionContext
---@param state rizu.editor.EditorNcbtActionState
---@param input rizu.editor.EditorNcbtActionInput
function EditorOverlayActionService:handleNcbtActionInput(context, state, input)
	if input.detectPressed then
		self:detectTempoOffset(context)
	end
	if state.canApply and input.applyPressed then
		self:applyNcbt(context)
	end
end

---@param context rizu.editor.EditorOverlayActionContext
function EditorOverlayActionService:applyNcbt(context)
	context:getAnalysisService():applyNcbt(context:getAnalysisContext())
end

---@param context rizu.editor.EditorOverlayActionContext
---@return number totalBeats
---@return number avgBeatDuration
function EditorOverlayActionService:getTotalBeats(context)
	return context:getAnalysisService():getTotalBeats(context:getAnalysisContext())
end

---@param context rizu.editor.EditorOverlayActionContext
---@return rizu.editor.EditorBeatSummaryState
function EditorOverlayActionService:getBeatSummaryState(context)
	local totalBeats, avgBeatDuration = self:getTotalBeats(context)
	local averageTempo = 60 / avgBeatDuration
	return {
		totalBeats = totalBeats,
		avgBeatDuration = avgBeatDuration,
		totalBeatsLabel = "Total beats: " .. totalBeats,
		averageTempoLabel = "Average tempo: " .. averageTempo .. " bpm",
	}
end

return EditorOverlayActionService
