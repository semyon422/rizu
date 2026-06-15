local class = require("class")

---@class yi.views.editor.EditorTimingOverlayPanel
---@operator call: yi.views.editor.EditorTimingOverlayPanel
local EditorTimingOverlayPanel = class()

---@param screen table
---@param panel yi.views.editor.EditorOverlayPanel
---@param overlayContext rizu.editor.EditorViewContext
function EditorTimingOverlayPanel:draw(screen, panel, overlayContext)
	local timingOverlayService = screen.editorViewServices.timingOverlayService
	local overlayActionService = screen.editorViewServices.overlayActionService

	local timingState = timingOverlayService:getState(overlayContext)

	timingOverlayService:handleNavigationInput(overlayContext, {
		prevPressed = panel:smallButton("prev tp", "<") and timingState.canScrollPrev,
		nextPressed = panel:smallButton("next tp", ">") and timingState.canScrollNext,
	})
	panel:endRow()
	panel:text(timingState.pointLabel)
	panel:text(timingState.pointStatusLabel)

	timingOverlayService:setShowTimings(
		overlayContext,
		panel:checkbox("show timings", timingState.showTimings, "show timings")
	)

	local ncbtActionState = overlayActionService:getNcbtActionState(overlayContext)
	overlayActionService:handleNcbtActionInput(overlayContext, ncbtActionState, {
		detectPressed = panel:button("ncbt", "detect tempo and offset"),
		applyPressed = ncbtActionState.canApply and panel:button("ncbt apply", "apply"),
	})

	panel:separator()

	if timingState.tempoLabel then
		panel:text(timingState.tempoLabel)
	end

	local splitPressed = false
	local grabPressed = false
	local dropPressed = false
	local mergePressed = false
	local newBeats = timingState.beats
	if timingState.canSplit then
		splitPressed = panel:button("split button", timingState.vertexActionLabel)
	elseif timingState.canGrab then
		grabPressed = panel:button("grab vertex button", timingState.vertexActionLabel)
	elseif timingState.canDrop then
		dropPressed = panel:button("drop vertex button", timingState.vertexActionLabel)
	end

	if timingState.canMerge then
		mergePressed = panel:button("merge vertex button", "merge")
	end
	if timingState.canEditBeats then
		newBeats = panel:slider("update vertex", timingState.beats, 1, 64, 1, timingState.beatsLabel)
	end
	timingOverlayService:handleVertexInput(overlayContext, timingState, {
		splitPressed = splitPressed,
		grabPressed = grabPressed,
		dropPressed = dropPressed,
		mergePressed = mergePressed,
		beats = newBeats,
	})

	panel:separator()

	local beatSummaryState = overlayActionService:getBeatSummaryState(overlayContext)
	panel:text(beatSummaryState.totalBeatsLabel)
	panel:text(beatSummaryState.averageTempoLabel)

	panel:separator()

	local commentState = timingOverlayService:getCommentState(overlayContext, timingState)
	if commentState then
		timingOverlayService:setCommentDraft(
			commentState,
			panel:input("vp comment", commentState.value, "comment")
		)
		if panel:button("save comment", "save") then
			screen.editorViewServices.overlayActionService:setVisualPointComment(commentState.visualPoint, commentState.value)
		end
		if panel:button("reset comment", "reset") then
			screen.editorViewServices.overlayActionService:resetVisualPointComment(commentState.visualPoint)
		end
	end
end

return EditorTimingOverlayPanel
