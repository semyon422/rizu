local class = require("class")
local View = require("gui.View")

---@class gui.Screen
---@operator call: gui.Screen
---@field root gui.View
---@field views gui.View[] All attached views in DFS pre-order
---@field update_views gui.View[] Views overriding View:update
---@field draw_views gui.View[] Views overriding View:draw
---@field dirty boolean
---@field width number Window width in drawable pixels
---@field height number Window height in drawable pixels
---@field ui_scale number Logical-per-drawable scale; root size = window / ui_scale
---@field inputs gui.Inputs?
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
	self.dirty = true
	self.inputs = nil
	self.pending_expire = {}
	self.width = 0
	self.height = 0
	self.ui_scale = 1
end

function Screen:invalidateLayout()
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
local function flatten(view, views, update_views, draw_views)
	local index = #views + 1
	view.flat_index = index
	views[index] = view

	if view.update ~= View.update then
		update_views[#update_views + 1] = view
	end
	if view.draw ~= View.draw then
		draw_views[#draw_views + 1] = view
	end

	for i = 1, #view.children do
		flatten(view.children[i], views, update_views, draw_views)
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
	flatten(self.root, views, update_views, draw_views)
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
		all_views[i]:stepTransforms(dt)
	end
	local views = self.update_views
	for i = 1, #views do
		views[i]:update(dt)
	end
end

function Screen:draw()
	self:flush()
	local views = self.draw_views
	for i = 1, #views do
		local view = views[i]
		if view.effective_visible and view.present then
			love.graphics.replaceTransform(view.world_transform)
			love.graphics.setScissor() -- clip_rect support lands with §9.1
			love.graphics.setColor(1, 1, 1, view.effective_opacity)
			view:draw()
		end
	end
	love.graphics.setScissor()
	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.origin()
end

---@param inputs gui.Inputs
function Screen:acceptInputs(inputs)
	self:flush()
	self.inputs = inputs
	local views = self.views
	for i = #views, 1, -1 do
		local view = views[i]
		if view.effective_visible and view.effective_enabled and view.present then
			inputs:processView(view)
		end
	end
end

return Screen
