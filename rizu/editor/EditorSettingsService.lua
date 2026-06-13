local class = require("class")

---@class rizu.editor.EditorSettingsService
---@operator call: rizu.editor.EditorSettingsService
local EditorSettingsService = class()

---@class rizu.editor.EditorSettingsContext
---@field getConfigModel fun(self: rizu.editor.EditorSettingsContext): sphere.ConfigModel
---@field getMaxSnap fun(self: rizu.editor.EditorSettingsContext): number

---@param editor table
---@param maxSnap number
---@return table
function EditorSettingsService:normalizeEditorSettings(editor, maxSnap)
	if editor.speed <= 0 then
		editor.speed = 1
	end
	editor.snap = math.min(math.max(editor.snap, 1), maxSnap)
	return editor
end

---@param configModel sphere.ConfigModel
---@param maxSnap number
---@return table
function EditorSettingsService:getSettings(configModel, maxSnap)
	return self:normalizeEditorSettings(configModel.configs.settings.editor, maxSnap)
end

---@param context rizu.editor.EditorSettingsContext
---@return table
function EditorSettingsService:getEditorSettings(context)
	return self:getSettings(context:getConfigModel(), context:getMaxSnap())
end

---@param configModel sphere.ConfigModel
---@return table
function EditorSettingsService:getAudioSettings(configModel)
	return configModel.configs.settings.audio
end

---@param context rizu.editor.EditorSettingsContext
---@return table
function EditorSettingsService:getEditorAudioSettings(context)
	return self:getAudioSettings(context:getConfigModel())
end

---@param editor table
---@return number
function EditorSettingsService:getLogSpeed(editor)
	return math.floor(10 * math.log(editor.speed, 2) + 0.5)
end

---@param context rizu.editor.EditorSettingsContext
---@return number
function EditorSettingsService:getEditorLogSpeed(context)
	return self:getLogSpeed(self:getEditorSettings(context))
end

---@param editor table
---@param logSpeed number
function EditorSettingsService:setLogSpeed(editor, logSpeed)
	editor.speed = 2 ^ (logSpeed / 10)
end

---@param context rizu.editor.EditorSettingsContext
---@param logSpeed number
function EditorSettingsService:setEditorLogSpeed(context, logSpeed)
	self:setLogSpeed(self:getEditorSettings(context), logSpeed)
end

---@param editor table
---@param maxSnap number
function EditorSettingsService:incSnap(editor, maxSnap)
	editor.snap = editor.snap * 2
	self:normalizeEditorSettings(editor, maxSnap)
end

---@param context rizu.editor.EditorSettingsContext
function EditorSettingsService:incEditorSnap(context)
	self:incSnap(self:getEditorSettings(context), context:getMaxSnap())
end

---@param editor table
---@param maxSnap number
function EditorSettingsService:decSnap(editor, maxSnap)
	editor.snap = math.floor(editor.snap / 2)
	self:normalizeEditorSettings(editor, maxSnap)
end

---@param context rizu.editor.EditorSettingsContext
function EditorSettingsService:decEditorSnap(context)
	self:decSnap(self:getEditorSettings(context), context:getMaxSnap())
end

---@param editor table
---@param j number|table
---@return number
function EditorSettingsService:getSnap(editor, j)
	local snap = editor.snap
	if type(j) == "table" then
		j, snap = 16 * j, 16
	end
	local k
	for i = 1, 16 do
		if snap % i == 0 and j % (snap / i) == 0 then
			k = i
			break
		end
	end
	return k
end

---@param context rizu.editor.EditorSettingsContext
---@param j number|table
---@return number
function EditorSettingsService:getEditorSnap(context, j)
	return self:getSnap(self:getEditorSettings(context), j)
end

---@param context rizu.editor.EditorSettingsContext
---@param editor table
---@return table
function EditorSettingsService:normalizeContextEditorSettings(context, editor)
	return self:normalizeEditorSettings(editor, context:getMaxSnap())
end

return EditorSettingsService
