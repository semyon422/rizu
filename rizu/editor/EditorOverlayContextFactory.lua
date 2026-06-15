local class = require("class")

---@class rizu.editor.EditorOverlayContextFactory
---@operator call: rizu.editor.EditorOverlayContextFactory
local EditorOverlayContextFactory = class()

---@param screen table
---@param overlayContext rizu.editor.EditorViewContext
---@return rizu.editor.EditorInfoOverlayContext
function EditorOverlayContextFactory:createInfoOverlayContext(screen, overlayContext)
	local metadata = screen.game.editorModel.metadata
	local editorController = screen.game.editorController

	return {
		iterMetadata = function()
			return metadata:iter()
		end,
		setMetadata = function(_, key, value)
			metadata:set(key, value)
		end,
		save = function()
			editorController:save()
		end,
		saveToOsu = function()
			editorController:saveToOsu()
		end,
		saveToNanoChart = function()
			editorController:saveToNanoChart()
		end,
	}
end

---@param screen table
---@param overlayContext rizu.editor.EditorViewContext
---@return rizu.editor.EditorBmsOverlayContext
function EditorOverlayContextFactory:createBmsOverlayContext(screen, overlayContext)
	local overlayActionService = screen.editorViewServices.overlayActionService
	local editorController = screen.game.editorController

	return {
		getBmsToolsContext = function()
			return overlayContext:getBmsToolsContext()
		end,
		applyBmsOffsetTempo = function()
			overlayActionService:applyBmsOffsetTempo(overlayContext)
		end,
		changeBmsOffset = function(_, delta)
			overlayActionService:changeBmsOffset(overlayContext, delta)
		end,
		sliceKeysounds = function()
			editorController:sliceKeysounds()
		end,
		exportBmsTemplate = function(_, columnsOut)
			editorController:exportBmsTemplate(columnsOut)
		end,
		exportUBmsC = function()
			editorController:exportUBmsC()
		end,
	}
end

return EditorOverlayContextFactory
