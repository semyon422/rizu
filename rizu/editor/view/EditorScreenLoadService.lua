local class = require("class")
local EditorViewServices = require("rizu.editor.view.EditorViewServices")

---@class rizu.editor.EditorScreenController
---@field load fun(self: rizu.editor.EditorScreenController)
---@field unload fun(self: rizu.editor.EditorScreenController)

---@class rizu.editor.EditorScreenPlayfield
---@field newNoteskinTransform fun(self: rizu.editor.EditorScreenPlayfield): table

---@class rizu.editor.EditorScreenGame
---@field editorController rizu.editor.EditorScreenController
---@field noteSkinModel {noteSkin: {playField: rizu.editor.EditorScreenPlayfield}}

---@class rizu.editor.EditorRetainedView
---@field load fun(self: rizu.editor.EditorRetainedView)
---@field unload (fun(self: rizu.editor.EditorRetainedView))?
---@field updateTransform fun(self: rizu.editor.EditorRetainedView)

---@class rizu.editor.EditorScreen
---@field game rizu.editor.EditorScreenGame
---@field loading boolean
---@field editor_loaded boolean
---@field editorViewServices rizu.editor.EditorViewServices?
---@field editor_retained_views rizu.editor.EditorRetainedView[]?
---@field views rizu.editor.EditorRetainedView[]
---@field snap_grid_transform table?
---@field transform table?
---@field editor_sequence_view gui.View?
---@field editor_snap_grid_view gui.View?
---@field editor_playfield_view gui.View?

---@class rizu.editor.EditorScreenLoadServiceDeps
---@field viewServicesFactory (fun(): rizu.editor.EditorViewServices)?
---@field retainedViewsFactory (fun(screen: rizu.editor.EditorScreen): rizu.editor.EditorRetainedView[])?

---@class rizu.editor.EditorScreenLoadService
---@operator call: rizu.editor.EditorScreenLoadService
---@field viewServicesFactory fun(): rizu.editor.EditorViewServices
---@field retainedViewsFactory fun(screen: rizu.editor.EditorScreen): rizu.editor.EditorRetainedView[]
local EditorScreenLoadService = class()

---@param deps rizu.editor.EditorScreenLoadServiceDeps
function EditorScreenLoadService:new(deps)
	self.viewServicesFactory = deps.viewServicesFactory or function()
		return EditorViewServices()
	end
	self.retainedViewsFactory = assert(deps.retainedViewsFactory, "retained editor views dependency is required")
end

---@param screen rizu.editor.EditorScreen
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
		screen.snap_grid_transform = nil
		error(err)
	end

	screen.editor_loaded = true
	screen.loading = false
	return true
end

---@param screen rizu.editor.EditorScreen
function EditorScreenLoadService:load(screen)
	local game = screen.game
	game.editorController:load()

	local noteSkin = game.noteSkinModel.noteSkin
	local playfield = noteSkin.playField
	local editorViewServices = self.viewServicesFactory()
	screen.editorViewServices = editorViewServices

	screen.snap_grid_transform = playfield:newNoteskinTransform()
	screen.transform = playfield:newNoteskinTransform()

	self:attachRetainedViews(screen)
end

---@param screen rizu.editor.EditorScreen
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

---@param screen rizu.editor.EditorScreen
function EditorScreenLoadService:detachRetainedViews(screen)
	local views = screen.editor_retained_views
	if not views then
		return
	end

	for _, view in ipairs(views) do
		if view.unload then
			view:unload()
		end
		for i, screenView in ipairs(screen.views) do
			if screenView == view then
				table.remove(screen.views, i)
				break
			end
		end
	end
	screen.editor_retained_views = nil
	screen.editor_sequence_view = nil
	screen.editor_snap_grid_view = nil
	screen.editor_playfield_view = nil
end

---@param screen rizu.editor.EditorScreen
---@return boolean unloaded
function EditorScreenLoadService:exit(screen)
	if not screen.editor_loaded then
		screen.loading = false
		return false
	end

	screen.game.editorController:unload()
	self:detachRetainedViews(screen)
	screen.editor_loaded = false
	screen.loading = false
	screen.editorViewServices = nil
	screen.editor_retained_views = nil
	screen.snap_grid_transform = nil
	return true
end

return EditorScreenLoadService
