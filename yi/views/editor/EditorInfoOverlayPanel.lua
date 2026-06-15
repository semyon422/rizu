local class = require("class")
local spherefonts = require("sphere.assets.fonts")

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

	love.graphics.push("all")
	love.graphics.setColor(1, 1, 1, 0.75)
	love.graphics.setFont(spherefonts.get("Noto Sans", 36))
	for i, label in ipairs(state.developmentLabels) do
		panel:label(label, 0, panel.cursorY + (i - 1) * 48, panel.panelWidth, 48)
	end
	love.graphics.pop()
	panel.cursorY = panel.cursorY + #state.developmentLabels * 48
end

return EditorInfoOverlayPanel
