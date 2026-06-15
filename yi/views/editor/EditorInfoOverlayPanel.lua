local class = require("class")

---@class yi.views.editor.EditorInfoOverlayPanel
---@operator call: yi.views.editor.EditorInfoOverlayPanel
local EditorInfoOverlayPanel = class()

---@param screen table
---@param panel yi.views.editor.EditorOverlayPanel
---@param infoOverlayContext rizu.editor.EditorInfoOverlayContext
function EditorInfoOverlayPanel:draw(screen, panel, infoOverlayContext)
	local infoOverlayService = screen.editorViewServices.infoOverlayService
	local state = infoOverlayService:getState(infoOverlayContext)

	panel:text(state.title)

	---@type {[string]: string}
	local metadata = {}
	for _, field in ipairs(state.fields) do
		metadata[field.key] = panel:input(field.inputId, field.value, field.key)
	end

	panel:separator()

	local savePressed = panel:smallButton("save btn", "save")
	local saveToOsuPressed = panel:smallButton("save to osu btn", "save osu")
	panel:endRow()
	local saveToNanoChartPressed = panel:button("save to nanochart btn", "save to nanochart")

	infoOverlayService:handleInput(infoOverlayContext, {
		metadata = metadata,
		savePressed = savePressed,
		saveToOsuPressed = saveToOsuPressed,
		saveToNanoChartPressed = saveToNanoChartPressed,
	})
end

return EditorInfoOverlayPanel
