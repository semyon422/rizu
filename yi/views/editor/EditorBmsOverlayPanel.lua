local class = require("class")

---@class yi.views.editor.EditorBmsOverlayPanel
---@operator call: yi.views.editor.EditorBmsOverlayPanel
local EditorBmsOverlayPanel = class()

---@param screen table
---@param panel yi.views.editor.EditorOverlayPanel
---@param bmsOverlayContext rizu.editor.EditorBmsOverlayContext
function EditorBmsOverlayPanel:draw(screen, panel, bmsOverlayContext)
	local bmsOverlayService = screen.editorViewServices.bmsOverlayService
	local bms_tools = bmsOverlayService:getBmsToolsContext(bmsOverlayContext)
	panel:text("BMS creation tools")

	bmsOverlayService:setOffsetTempo(
		bmsOverlayContext,
		tonumber(panel:input("offset", bms_tools.offset, "offset")) or 0,
		tonumber(panel:input("tempo", bms_tools.tempo, "tempo")) or 120
	)

	if panel:button("bms apply tempo", "apply") then
		bmsOverlayService:applyOffsetTempo(bmsOverlayContext)
	end

	panel:text("offset")
	if panel:smallButton("bms add offset", "+1ms") then
		bmsOverlayService:changeOffset(bmsOverlayContext, 0.001)
	end
	if panel:smallButton("bms sub offset", "-1ms") then
		bmsOverlayService:changeOffset(bmsOverlayContext, -0.001)
	end
	panel:endRow()

	if panel:button("slice keysounds", "slice keysounds") then
		bmsOverlayService:sliceKeysounds(bmsOverlayContext)
	end

	bmsOverlayService:setBeatOffset(
		bmsOverlayContext,
		tonumber(panel:input("beat_offset", bms_tools.beat_offset, "beat offset")) or 0
	)
	if panel:button("create bms template 5K", "create bms template 5K") then
		bmsOverlayService:exportBmsTemplate(bmsOverlayContext, 5)
	end
	if panel:button("create bms template 7K", "create bms template 7K") then
		bmsOverlayService:exportBmsTemplate(bmsOverlayContext, 7)
	end
	if panel:button("create bms template 10K", "create bms template 10K") then
		bmsOverlayService:exportBmsTemplate(bmsOverlayContext, 10)
	end
	if panel:button("export ubmsc", "export ubmsc") then
		bmsOverlayService:exportUBmsC(bmsOverlayContext)
	end
end

return EditorBmsOverlayPanel
