local class = require("class")

---@class rizu.editor.EditorLoadContext
---@field setLoaded fun(loaded: boolean)
---@field getSettings fun(): table
---@field loadChartData fun()
---@field resetState fun()
---@field loadTimer fun(editor: table)
---@field loadAudio fun()
---@field loadMetronome fun()
---@field loadInitialScroll fun()
---@field loadBmsToolsContext fun()
---@field loadMetadata fun()

---@class rizu.editor.EditorLoadService
---@operator call: rizu.editor.EditorLoadService
local EditorLoadService = class()

---@param context rizu.editor.EditorLoadContext
function EditorLoadService:load(context)
	context.setLoaded(true)

	local editor = context.getSettings()

	context.loadChartData()
	context.resetState()
	context.loadTimer(editor)
	context.loadAudio()
	context.loadMetronome()
	context.loadInitialScroll()
	context.loadBmsToolsContext()
	context.loadMetadata()
end

return EditorLoadService
