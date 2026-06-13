local class = require("class")

---@alias rizu.editor.MetadataEditFunc fun(key: string, value: string)

---@class rizu.editor.EditorInfoOverlayContext
---@field iterMetadata fun(self: rizu.editor.EditorInfoOverlayContext): fun(): string?, string?
---@field setMetadata fun(self: rizu.editor.EditorInfoOverlayContext, key: string, value: string)
---@field save fun(self: rizu.editor.EditorInfoOverlayContext)
---@field saveToOsu fun(self: rizu.editor.EditorInfoOverlayContext)
---@field saveToNanoChart fun(self: rizu.editor.EditorInfoOverlayContext)

---@class rizu.editor.EditorInfoOverlayService
---@operator call: rizu.editor.EditorInfoOverlayService
local EditorInfoOverlayService = class()

---@param context rizu.editor.EditorInfoOverlayContext
---@param edit rizu.editor.MetadataEditFunc
function EditorInfoOverlayService:editMetadata(context, edit)
	for key, value in context:iterMetadata() do
		context:setMetadata(key, edit(key, value))
	end
end

---@param context rizu.editor.EditorInfoOverlayContext
function EditorInfoOverlayService:save(context)
	context:save()
end

---@param context rizu.editor.EditorInfoOverlayContext
function EditorInfoOverlayService:saveToOsu(context)
	context:saveToOsu()
end

---@param context rizu.editor.EditorInfoOverlayContext
function EditorInfoOverlayService:saveToNanoChart(context)
	context:saveToNanoChart()
end

return EditorInfoOverlayService
