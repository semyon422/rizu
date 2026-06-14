local class = require("class")
local SequenceView = require("sphere.views.SequenceView")
local SnapGridView = require("ui.views.EditorView.SnapGridView")
local EditorViewServices = require("rizu.editor.EditorViewServices")
local EditorRetainedViews = require("ui.views.EditorView.retained.EditorRetainedViews")

---@class rizu.editor.EditorScreenLoadServiceDeps
---@field sequenceViewFactory (fun(): table)?
---@field snapGridViewFactory (fun(): table)?
---@field viewServicesFactory (fun(): rizu.editor.EditorViewServices)?
---@field retainedViewsFactory (fun(screen: table): gui.View[])?

---@class rizu.editor.EditorScreenLoadService
---@operator call: rizu.editor.EditorScreenLoadService
---@field sequenceViewFactory fun(): table
---@field snapGridViewFactory fun(): table
---@field viewServicesFactory fun(): rizu.editor.EditorViewServices
---@field retainedViewsFactory fun(screen: table): gui.View[]
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
	self.viewServicesFactory = deps.viewServicesFactory or function()
		return EditorViewServices()
	end
	self.retainedViewsFactory = deps.retainedViewsFactory or EditorRetainedViews
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
		screen.editorViewServices = nil
		self:detachRetainedViews(screen)
		screen.snap_grid_view = nil
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
	local editorViewServices = self.viewServicesFactory()
	screen.editorViewServices = editorViewServices

	local snapGridView = self.snapGridViewFactory()
	snapGridView.game = game
	snapGridView.editorViewServices = editorViewServices
	snapGridView.transform = playfield:newNoteskinTransform()
	screen.snap_grid_view = snapGridView
	screen.transform = playfield:newNoteskinTransform()

	local sequenceView = screen.sequence_view or self.sequenceViewFactory()
	sequenceView.game = game
	sequenceView.subscreen = "editor"
	sequenceView:setSequenceConfig(playfield)
	sequenceView:load()
	screen.sequence_view = sequenceView

	self:attachRetainedViews(screen)
end

---@param screen table
function EditorScreenLoadService:attachRetainedViews(screen)
	local views = self.retainedViewsFactory(screen)
	screen.editor_retained_views = views
	screen.views = screen.views or {}

	for _, view in ipairs(views) do
		table.insert(screen.views, view)
		view:load()
		view:updateTransform()
	end
end

---@param screen table
function EditorScreenLoadService:detachRetainedViews(screen)
	local views = screen.editor_retained_views
	if not views then
		return
	end

	for _, view in ipairs(views) do
		for i, screenView in ipairs(screen.views) do
			if screenView == view then
				table.remove(screen.views, i)
				break
			end
		end
	end
	screen.editor_retained_views = nil
end

---@param screen table
---@return boolean unloaded
function EditorScreenLoadService:exit(screen)
	if not screen.editor_loaded then
		screen.loading = false
		return false
	end

	screen.game.editorController:unload()
	self:detachRetainedViews(screen)
	screen.sequence_view:unload()
	screen.editor_loaded = false
	screen.loading = false
	screen.editorViewServices = nil
	screen.editor_retained_views = nil
	screen.snap_grid_view = nil
	return true
end

return EditorScreenLoadService
