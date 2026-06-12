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

---@param editorModel rizu.editor.EditorModel
---@return table
function EditorSettingsService:getSettings(editorModel)
	return self:normalizeEditorSettings(editorModel.configModel.configs.settings.editor, editorModel.max_snap)
end

---@param editorModel rizu.editor.EditorModel
---@return table
function EditorSettingsService:getAudioSettings(editorModel)
	return editorModel.configModel.configs.settings.audio
end

---@param editorModel rizu.editor.EditorModel
---@return number
function EditorSettingsService:getLogSpeed(editorModel)
	local editor = self:getSettings(editorModel)
	return math.floor(10 * math.log(editor.speed, 2) + 0.5)
end

---@param editorModel rizu.editor.EditorModel
---@param logSpeed number
function EditorSettingsService:setLogSpeed(editorModel, logSpeed)
	local editor = self:getSettings(editorModel)
	editor.speed = 2 ^ (logSpeed / 10)
end

---@param editorModel rizu.editor.EditorModel
function EditorSettingsService:incSnap(editorModel)
	local editor = self:getSettings(editorModel)
	editor.snap = editor.snap * 2
	self:normalizeEditorSettings(editor, editorModel.max_snap)
end

---@param editorModel rizu.editor.EditorModel
function EditorSettingsService:decSnap(editorModel)
	local editor = self:getSettings(editorModel)
	editor.snap = math.floor(editor.snap / 2)
	self:normalizeEditorSettings(editor, editorModel.max_snap)
end

---@param editorModel rizu.editor.EditorModel
---@param j number|table
---@return number
function EditorSettingsService:getSnap(editorModel, j)
	local editor = self:getSettings(editorModel)
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
