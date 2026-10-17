local class = require("class")

---@class rizu.editor.EditorInfoOverlayState
---@field title string
---@field fields rizu.editor.EditorInfoMetadataField[]

---@class rizu.editor.EditorInfoMetadataField
---@field key string
---@field value string
---@field inputId string

---@class rizu.editor.EditorInfoOverlayInput
---@field metadata {[string]: string}
---@field savePressed boolean
---@field saveToOsuPressed boolean
---@field saveToNanoChartPressed boolean

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
---@return rizu.editor.EditorInfoOverlayState
function EditorInfoOverlayService:getState(context)
	local fields = {}
	for key, value in context:iterMetadata() do
		fields[#fields + 1] = {
			key = key,
			value = value,
			inputId = key .. " input",
		}
	end
	return {
		title = "Chart info",
		fields = fields,
	}
end

---@param context rizu.editor.EditorInfoOverlayContext
---@param input rizu.editor.EditorInfoOverlayInput
function EditorInfoOverlayService:handleInput(context, input)
	for key, value in pairs(input.metadata) do
		context:setMetadata(key, value)
	end
	if input.savePressed then
		self:save(context)
	end
	if input.saveToOsuPressed then
		self:saveToOsu(context)
	end
	if input.saveToNanoChartPressed then
		self:saveToNanoChart(context)
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
