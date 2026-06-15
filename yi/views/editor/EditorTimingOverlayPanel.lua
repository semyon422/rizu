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

	local dtp = timingOverlayService:getPoint(overlayContext)

	if panel:smallButton("prev tp", "<") and dtp.prev then
		timingOverlayService:scrollPrev(overlayContext)
	end
	if panel:smallButton("next tp", ">") and dtp.next then
		timingOverlayService:scrollNext(overlayContext)
	end
	panel:endRow()
	panel:text(tostring(dtp))

	timingOverlayService:setShowTimings(
		overlayContext,
		panel:checkbox("show timings", timingOverlayService:isShowTimings(overlayContext), "show timings")
	)

	if panel:button("ncbt", "detect tempo and offset") then
		overlayActionService:detectTempoOffset(overlayContext)
	end
	if overlayActionService:hasDetectedTempoOffset(overlayContext) and panel:button("ncbt apply", "apply") then
		overlayActionService:applyNcbt(overlayContext)
	end

	panel:separator()

	local vertex = dtp._vertex
	if dtp.vertex then
		panel:text("Tempo: " .. dtp.vertex:getTempo() .. " bpm")
	end

	if not timingOverlayService:isGrabbed(overlayContext) then
		if not vertex then
			if panel:button("split button", "split") then
				timingOverlayService:split(overlayContext, dtp)
			end
		elseif panel:button("grab vertex button", "grab") then
			timingOverlayService:grab(overlayContext, vertex)
		end
	elseif panel:button("drop vertex button", "drop") then
		timingOverlayService:drop(overlayContext)
	end

	if vertex and not timingOverlayService:isGrabbed(overlayContext) then
		if panel:button("merge vertex button", "merge") then
			timingOverlayService:merge(overlayContext, vertex.point)
		end
		local beats = vertex.beats
		local newBeats = panel:slider("update vertex", beats, 1, 64, 1, "beats " .. beats)
		if beats ~= newBeats then
			timingOverlayService:update(overlayContext, vertex, newBeats)
		end
	end

	panel:separator()

	local totalBeats, avgBeatDuration = overlayActionService:getTotalBeats(overlayContext)
	panel:text("Total beats: " .. totalBeats)
	panel:text("Average tempo: " .. 60 / avgBeatDuration .. " bpm")

	panel:separator()

	local vp = timingOverlayService:getCommentVisualPoint(overlayContext, dtp)
	if vp then
		vp.temp_comment = panel:input("vp comment", vp.temp_comment or vp.comment, "comment")
		if panel:button("save comment", "save") then
			screen.editorViewServices.overlayActionService:setVisualPointComment(vp, vp.temp_comment)
		end
		if panel:button("reset comment", "reset") then
			screen.editorViewServices.overlayActionService:resetVisualPointComment(vp)
		end
	end
end

return EditorTimingOverlayPanel
