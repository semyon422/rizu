local class = require("class")
local spherefonts = require("sphere.assets.fonts")

---@class yi.views.editor.EditorInfoOverlayPanel
---@operator call: yi.views.editor.EditorInfoOverlayPanel
local EditorInfoOverlayPanel = class()

---@param screen table
---@param panel yi.views.editor.EditorOverlayPanel
---@param infoOverlayContext rizu.editor.EditorInfoOverlayContext
function EditorInfoOverlayPanel:draw(screen, panel, infoOverlayContext)
	panel:text("Chart info")

	local infoOverlayService = screen.editorViewServices.infoOverlayService
	infoOverlayService:editMetadata(infoOverlayContext, function(key, value)
		return panel:input(key .. " input", value, key)
	end)

	panel:separator()

	if panel:smallButton("save btn", "save") then
		infoOverlayService:save(infoOverlayContext)
	end
	if panel:smallButton("save to osu btn", "save osu") then
		infoOverlayService:saveToOsu(infoOverlayContext)
	end
	panel:endRow()
	if panel:button("save to nanochart btn", "save to nanochart") then
		infoOverlayService:saveToNanoChart(infoOverlayContext)
	end

	love.graphics.push("all")
	love.graphics.setColor(1, 1, 1, 0.75)
	love.graphics.setFont(spherefonts.get("Noto Sans", 36))
	panel:label("The editor", 0, panel.cursorY, panel.panelWidth, 48)
	panel:label("is in development", 0, panel.cursorY + 48, panel.panelWidth, 48)
	love.graphics.pop()
	panel.cursorY = panel.cursorY + 96
end

return EditorInfoOverlayPanel
