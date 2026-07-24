local class = require("class")
local Renderer = require("gui.Renderer")
local View = require("gui.View")

---@class gui.Screen
---@operator call: gui.Screen
---@field root gui.View
---@field views gui.View[] All attached views in DFS pre-order
---@field update_views gui.View[] Views overriding View:update
---@field draw_views gui.View[] Views overriding View:draw
---@field renderer gui.Renderer
---@field dirty boolean
---@field width number Window width in drawable pixels
---@field height number Window height in drawable pixels
---@field ui_scale number Logical-per-drawable scale; root size = window / ui_scale
---@field inputs gui.Inputs?
---@field loaded boolean
---@field private pending_expire {[gui.View]: true}
local Screen = class()

function Screen:new()
	self.root = View()
	self.root:setScreen(self)
	---@type gui.View[]
	self.views = {}
	---@type gui.View[]
	self.update_views = {}
	---@type gui.View[]
	self.draw_views = {}
	self.renderer = Renderer()
	self.dirty = true
	self.inputs = nil
	self.loaded = false
	self.pending_expire = {}
	self.width = 0
	self.height = 0
	self.ui_scale = 1
end

function Screen:invalidateLayout()
	self.dirty = true
end

---Called when this becomes the input screen.
function Screen:enter()
end

---Called before another screen becomes the input screen.
---Returning false vetoes the change.
---@return boolean can_exit
function Screen:exit()
	if self.inputs then
		self.inputs:clearSubtree(self.root)
		self.inputs = nil
	end
	return true
end

function Screen:load()
	if self.loaded then
		return
	end
	self.loaded = true
	self.root:loadSubtree()
	self:flush()
end

function Screen:unload()
	if not self.loaded then
		return
	end
	if self.inputs then
		self.inputs:clearSubtree(self.root)
	end
	self.root:unloadSubtree()
	self.loaded = false
	self.views = {}
	self.update_views = {}
	self.draw_views = {}
	self.renderer:clear()
	self.inputs = nil
	self.dirty = true
end

---@param view gui.View
function Screen:queueExpire(view)
	self.pending_expire[view] = true
	self.dirty = true
end

---@private
function Screen:removeExpiredViews()
	local pending = self.pending_expire
	self.pending_expire = {}
	-- Removing an expired ancestor detaches its whole subtree; descendants are
	-- revalidated before removal.
	for view in pairs(pending) do
		if view.screen == self and view.expired and not view:hasTransforms() and view.parent then
			view.parent:remove(view)
		end
	end
end

---@param view gui.View
---@param renderer gui.Renderer
local function flatten(view, views, update_views, draw_views, renderer)
	local index = #views + 1
	view.flat_index = index
	views[index] = view

	if view.update ~= View.update then
		update_views[#update_views + 1] = view
	end
	if view.draw ~= View.draw then
		draw_views[#draw_views + 1] = view
		if not view.is_composite then
			renderer:addView(view)
		end
	end

	if view.is_composite then
		---@cast view gui.CompositeView
		renderer:beginComposite(view)
	end
	for i = 1, #view.children do
		flatten(view.children[i], views, update_views, draw_views, renderer)
	end
	if view.is_composite then
		renderer:endComposite()
	end
	view.flat_subtree_end = #views
end

---Rebuild traversal caches after resolving and composing the tree.
function Screen:relayout()
	-- Clear first so invalidation triggered during the rebuild survives.
	self.dirty = false
	self.root:relayout(self.ui_scale)

	local views = {} ---@type gui.View[]
	local update_views = {} ---@type gui.View[]
	local draw_views = {} ---@type gui.View[]
	self.renderer:beginBuild()
	flatten(self.root, views, update_views, draw_views, self.renderer)
	self.views = views
	self.update_views = update_views
	self.draw_views = draw_views
end

---Run at most one pending tree rebuild.
function Screen:flush()
	self:removeExpiredViews()
	if not self.dirty then
		return
	end
	-- Clear first so invalidation during the rebuild is not lost.
	self.dirty = false
	self:relayout()
end

---@param w number Window width in drawable pixels
---@param h number Window height in drawable pixels
function Screen:resize(w, h)
	self.width = w
	self.height = h
	local scale = self.ui_scale
	local root = self.root
	root.x = 0
	root.y = 0
	root.width = w / scale
	root.height = h / scale
	self:invalidateLayout()
	-- Preserve resize's synchronous geometry contract. Other invalidations are
	-- coalesced until flush.
	self:flush()
end

---@param scale number Finite positive scale
function Screen:setUIScale(scale)
	assert(type(scale) == "number" and scale > 0 and scale < math.huge,
		"ui_scale must be a positive finite number")
	self.ui_scale = scale
	if self.width > 0 and self.height > 0 then
		self:resize(self.width, self.height)
	else
		self:invalidateLayout()
	end
end

---@param dt number
function Screen:update(dt)
	self:flush()
	-- Animations settle first so view update code always observes this frame's
	-- visual state (§7.3, §11.1). Use the complete flat cache: inert layout
	-- views can still own whole-subtree animations.
	local all_views = self.views
	for i = 1, #all_views do
		local view = all_views[i]
		if not view.detached then
			view:stepTransforms(dt)
		end
	end
	local views = self.update_views
	for i = 1, #views do
		local view = views[i]
		if not view.detached then
			view:update(dt)
		end
	end
end

---Print resolved and authored layout data for named views.
function Screen:printDebugLayout()
	self:flush()
	print("GUI layout:")
	for _, view in ipairs(self.views) do
		if view.debug_name then
			local depth = 0
			local parent = view.parent
			while parent do
				depth = depth + 1
				parent = parent.parent
			end
			local arranged = view.arranged
			local source = arranged and ("arranged={%.1f, %.1f, %.1f, %.1f}"):format(
				arranged[1], arranged[2], arranged[3], arranged[4]
			) or "anchors"
			print(("%s%s: rect={%.1f, %.1f, %.1f, %.1f} source=%s"):format(
				string.rep("  ", depth), view.debug_name,
				view.x, view.y, view.width, view.height, source
			))
			print(("%sanchors={{%.2f, %.2f}, {%.2f, %.2f}} offsets={{%.1f, %.1f}, {%.1f, %.1f}} modes={%s, %s}"):format(
				string.rep("  ", depth + 1),
				view.anchor_min[1], view.anchor_min[2], view.anchor_max[1], view.anchor_max[2],
				view.offset_min[1], view.offset_min[2], view.offset_max[1], view.offset_max[2],
				view.size_mode_x, view.size_mode_y
			))
		end
	end
end

function Screen:draw()
	self:flush()
	self.renderer:draw()
end

---@param inputs gui.Inputs
function Screen:acceptInputs(inputs)
	self:flush()
	self.inputs = inputs
	local views = self.views
	for i = #views, 1, -1 do
		local view = views[i]
		if not view.detached and view.effective_visible and view.effective_enabled and view.present then
			inputs:processView(view)
		end
	end
end

return Screen
