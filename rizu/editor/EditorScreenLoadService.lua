local class = require("class")
local SequenceView = require("sphere.views.SequenceView")
local SnapGridView = require("ui.views.EditorView.SnapGridView")

---@class rizu.editor.EditorScreenLoadServiceDeps
---@field sequenceViewFactory (fun(): table)?
---@field snapGridViewFactory (fun(): table)?

---@class rizu.editor.EditorScreenLoadService
---@operator call: rizu.editor.EditorScreenLoadService
---@field sequenceViewFactory fun(): table
---@field snapGridViewFactory fun(): table
local EditorScreenLoadService = class()

---@param deps rizu.editor.EditorScreenLoadServiceDeps?
function EditorScreenLoadService:new(deps)
	deps = deps or {}
	self.sequenceViewFactory = deps.sequenceViewFactory or function()
		return SequenceView()
	end
	self.snapGridViewFactory = deps.snapGridViewFactory or function()
		return SnapGridView()
	end
end

---@param screen table
---@return boolean started
function EditorScreenLoadService:enter(screen)
	if screen.loading or screen.editor_loaded then
		return false
	end

	screen.loading = true
	local ok, err = xpcall(function()
		self:load(screen)
	end, debug.traceback)

	if not ok then
		screen.loading = false
		screen.editor_loaded = false
		error(err)
	end

	screen.editor_loaded = true
	screen.loading = false
	return true
end

---@param screen table
function EditorScreenLoadService:load(screen)
	local game = screen.game
	game.editorController:load()

	local noteSkin = game.noteSkinModel.noteSkin
	local playfield = noteSkin.playField

	local snapGridView = self.snapGridViewFactory()
	snapGridView.game = game
	snapGridView.transform = playfield:newNoteskinTransform()
	screen.snap_grid_view = snapGridView
	screen.transform = playfield:newNoteskinTransform()

	local sequenceView = screen.sequence_view or self.sequenceViewFactory()
	sequenceView.game = game
	sequenceView.subscreen = "editor"
	sequenceView:setSequenceConfig(playfield)
	sequenceView:load()
	screen.sequence_view = sequenceView
end

---@param screen table
---@return boolean unloaded
function EditorScreenLoadService:exit(screen)
	if not screen.editor_loaded then
		screen.loading = false
		return false
	end

	screen.game.editorController:unload()
	screen.sequence_view:unload()
	screen.editor_loaded = false
	screen.loading = false
	return true
end

return EditorScreenLoadService
