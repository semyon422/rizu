local class = require("class")

---@class rizu.editor.EditorSettingsService
---@operator call: rizu.editor.EditorSettingsService
local EditorSettingsService = class()

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

---@param configModel sphere.ConfigModel
---@return table
function EditorSettingsService:getAudioSettings(configModel)
	return configModel.configs.settings.audio
end

---@param editor table
---@return number
function EditorSettingsService:getLogSpeed(editor)
	return math.floor(10 * math.log(editor.speed, 2) + 0.5)
end

---@param editor table
---@param logSpeed number
function EditorSettingsService:setLogSpeed(editor, logSpeed)
	editor.speed = 2 ^ (logSpeed / 10)
end

---@param editor table
---@param maxSnap number
function EditorSettingsService:incSnap(editor, maxSnap)
	editor.snap = editor.snap * 2
	self:normalizeEditorSettings(editor, maxSnap)
end

---@param editor table
---@param maxSnap number
function EditorSettingsService:decSnap(editor, maxSnap)
	editor.snap = math.floor(editor.snap / 2)
	self:normalizeEditorSettings(editor, maxSnap)
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

return EditorSettingsService
