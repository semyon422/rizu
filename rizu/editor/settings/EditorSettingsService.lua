local class = require("class")

---@class rizu.editor.EditorSettings
---@field speed number
---@field snap integer
---@field showTimings boolean

---@class rizu.editor.EditorSettingsService
---@operator call: rizu.editor.EditorSettingsService
local EditorSettingsService = class()

---@class rizu.editor.EditorSettingsContext
---@field getConfigModel fun(self: rizu.editor.EditorSettingsContext): sphere.ConfigModel
---@field getMaxSnap fun(self: rizu.editor.EditorSettingsContext): number

---@param editor rizu.editor.EditorSettings
---@param maxSnap number
---@return rizu.editor.EditorSettings
function EditorSettingsService:normalizeEditorSettings(editor, maxSnap)
	if editor.speed <= 0 then
		editor.speed = 1
	end
	editor.snap = math.min(math.max(editor.snap, 1), maxSnap)
	return editor
end

---@param configModel sphere.ConfigModel
---@param maxSnap number
---@return rizu.editor.EditorSettings
function EditorSettingsService:getSettings(configModel, maxSnap)
	return self:normalizeEditorSettings(configModel.configs.settings.editor, maxSnap)
end

---@param context rizu.editor.EditorSettingsContext
---@return rizu.editor.EditorSettings
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

---@param editor rizu.editor.EditorSettings
---@return number
function EditorSettingsService:getLogSpeed(editor)
	return math.floor(10 * math.log(editor.speed, 2) + 0.5)
end

---@param context rizu.editor.EditorSettingsContext
---@return number
function EditorSettingsService:getEditorLogSpeed(context)
	return self:getLogSpeed(self:getEditorSettings(context))
end

---@param editor rizu.editor.EditorSettings
---@param logSpeed number
function EditorSettingsService:setLogSpeed(editor, logSpeed)
	editor.speed = 2 ^ (logSpeed / 10)
end

---@param context rizu.editor.EditorSettingsContext
---@param logSpeed number
function EditorSettingsService:setEditorLogSpeed(context, logSpeed)
	self:setLogSpeed(self:getEditorSettings(context), logSpeed)
end

---@param editor rizu.editor.EditorSettings
---@param maxSnap number
function EditorSettingsService:incSnap(editor, maxSnap)
	editor.snap = editor.snap * 2
	self:normalizeEditorSettings(editor, maxSnap)
end

---@param context rizu.editor.EditorSettingsContext
function EditorSettingsService:incEditorSnap(context)
	self:incSnap(self:getEditorSettings(context), context:getMaxSnap())
end

---@param editor rizu.editor.EditorSettings
---@param maxSnap number
function EditorSettingsService:decSnap(editor, maxSnap)
	editor.snap = math.floor(editor.snap / 2)
	self:normalizeEditorSettings(editor, maxSnap)
end

---@param context rizu.editor.EditorSettingsContext
function EditorSettingsService:decEditorSnap(context)
	self:decSnap(self:getEditorSettings(context), context:getMaxSnap())
end

---@param editor rizu.editor.EditorSettings
---@param j number|chart.Fraction
---@return integer
function EditorSettingsService:getSnap(editor, j)
	local snap = editor.snap
	---@type number
	local position
	if type(j) == "table" then
		position, snap = 16 * j:tonumber(), 16
	else
		position = j
	end
	---@type integer
	local k
	for i = 1, 16 do
		if snap % i == 0 and position % (snap / i) == 0 then
			k = i
			break
		end
	end
	return k
end

---@param context rizu.editor.EditorSettingsContext
---@param j number|chart.Fraction
---@return number
function EditorSettingsService:getEditorSnap(context, j)
	return self:getSnap(self:getEditorSettings(context), j)
end

---@param context rizu.editor.EditorSettingsContext
---@param editor rizu.editor.EditorSettings
---@return rizu.editor.EditorSettings
function EditorSettingsService:normalizeContextEditorSettings(context, editor)
	return self:normalizeEditorSettings(editor, context:getMaxSnap())
end

return EditorSettingsService
