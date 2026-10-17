local class = require("class")
local Renderer = require("gui.Renderer")
local Animation = require("gui.view.Animation")
local View = require("gui.View")

---@class gui.Screen
---@operator call: gui.Screen
---@field root gui.View
---@field views gui.View[] All attached views in DFS pre-order
---@field input_views gui.View[] Views overriding View:onHandleInputs
---@field update_views gui.View[] Views overriding View:update
---@field renderer gui.Renderer
---@field dirty boolean
---@field width number Window width in drawable pixels
---@field height number Window height in drawable pixels
---@field ui_scale number Logical-per-drawable scale; root size = window / ui_scale
---@field inputs gui.Inputs?
---@field loaded boolean
---@field pending_unload {[gui.View]: true}
---@field private pending_expire {[gui.View]: true}
---@field private animating {[gui.View]: true} Attached views with a running transform or layout glide
---@field private animation_views gui.View[] Scratch list for one animation step
---@field private animation_kinds integer[]
local Screen = class()

function Screen:new()
	self.animating = {}
	self.animation_views = {}
	self.animation_kinds = {}
	self.root = View()
	self.root:setScreen(self)
	---@type gui.View[]
	self.views = {}
	---@type gui.View[]
	self.input_views = {}
	---@type gui.View[]
	self.update_views = {}
	self.renderer = Renderer()
	self.dirty = true
	self.inputs = nil
	self.loaded = false
	self.pending_unload = {}
	self.pending_expire = {}
	self.width = 0
	self.height = 0
	self.ui_scale = 1
end

function Screen:invalidateLayout()
	self.dirty = true
end

---Receives a raw LÖVE or application event while this screen is active.
---@param event {name: string, time: number, [integer]: any}
---@return boolean? handled
function Screen:receive(event)
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
	self:flushPendingUnload()
	self.root:unloadSubtree()
	self.loaded = false
	self.views = {}
	self.input_views = {}
	self.update_views = {}
	self.renderer:clear()
	self.inputs = nil
	self.pending_unload = {}
	self.pending_expire = {}
	self.dirty = true
end

---@param view gui.View
function Screen:queueUnload(view)
	assert(not view.pending_unload_screen, "view is already pending unload")
	view.pending_unload_screen = self
	self.pending_unload[view] = true
end

---@param view gui.View
function Screen:cancelUnload(view)
	assert(view.pending_unload_screen == self and self.pending_unload[view],
		"view is not pending unload from this screen")
	self.pending_unload[view] = nil
	view.pending_unload_screen = nil
end

---Unload one queued subtree immediately, or all queued subtrees when omitted.
---The single-view form is used to preserve unload-before-load ordering during
---cross-screen moves.
---@param only_view gui.View?
function Screen:flushPendingUnload(only_view)
	local pending = self.pending_unload
	if next(pending) == nil then
		return
	end
	if only_view then
		if not pending[only_view] then
			return
		end
		pending[only_view] = nil
		if self.inputs then
			self.inputs:clearSubtree(only_view)
		end
		only_view:unloadSubtree()
		only_view.pending_unload_screen = nil
		return
	end

	self.pending_unload = {}
	for view in pairs(pending) do
		if self.inputs then
			self.inputs:clearSubtree(view)
		end
		view:unloadSubtree()
		view.pending_unload_screen = nil
	end
end

---@param view gui.View
function Screen:queueExpire(view)
	self.pending_expire[view] = true
	self.dirty = true
end

---@private
function Screen:removeExpiredViews()
	local pending = self.pending_expire
	if next(pending) == nil then
		return
	end
	self.pending_expire = {}
	-- Removing an expired ancestor detaches its whole subtree; descendants are
	-- revalidated before removal.
	for view in pairs(pending) do
		if view.screen == self and view.expired and not view:hasTransforms() and view.parent then
			view.parent:remove(view)
		end
	end
end

---@param views gui.View[]
---@param input_views gui.View[]
---@param update_views gui.View[]
---@param after_layout_views gui.View[]
---@param view gui.View
---@param renderer gui.Renderer
local function flatten(view, views, input_views, update_views, after_layout_views, renderer)
	local index = #views + 1
	view.flat_index = index
	views[index] = view

	if view.onHandleInputs ~= View.onHandleInputs then
		input_views[#input_views + 1] = view
	end
	if view.update ~= View.update then
		update_views[#update_views + 1] = view
	end
	if view.afterLayout then
		after_layout_views[#after_layout_views + 1] = view
	end
	-- A composite's own draw belongs to its content, so it goes inside the boundary.
	local composite_slot, draw_slot ---@type integer?, integer?
	if view.is_composite then
		---@cast view gui.CompositeView
		composite_slot = renderer:beginComposite(view)
	end
	if view.draw ~= View.draw then
		draw_slot = renderer:addView(view)
	end
	for i = 1, #view.children do
		flatten(view.children[i], views, input_views, update_views, after_layout_views, renderer)
	end
	if draw_slot then
		renderer:endSubtree(draw_slot)
	end
	if composite_slot then
		renderer:endComposite()
		renderer:endSubtree(composite_slot)
	end
	view.flat_subtree_end = #views
end

---Rebuild traversal caches after resolving and composing the tree.
function Screen:relayout()
	-- Clear first so invalidation triggered during the rebuild survives.
	self.dirty = false
	self.root:relayout(self.ui_scale)

	local views = {} ---@type gui.View[]
	local input_views = {} ---@type gui.View[]
	local update_views = {} ---@type gui.View[]
	local after_layout_views = {} ---@type gui.View[]
	self.renderer:beginBuild()
	flatten(self.root, views, input_views, update_views, after_layout_views, self.renderer)
	self.views = views
	self.input_views = input_views
	self.update_views = update_views
	for i = 1, #after_layout_views do
		after_layout_views[i]:afterLayout()
	end
end

---Run at most one pending tree rebuild.
function Screen:flush()
	self:removeExpiredViews()
	self:flushPendingUnload()
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

---@return boolean active
function Screen:isTransitionActive()
	if not self.root.present then
		return false
	end
	for view in pairs(self.animating) do
		if view:isAnimating() then
			return true
		end
	end
	return false
end

---Views call this when they start animating while attached, or attach while animating.
---@param view gui.View
function Screen:trackAnimation(view)
	self.animating[view] = true
end

---@param view gui.View
function Screen:untrackAnimation(view)
	self.animating[view] = nil
end

---@param a gui.View
---@param b gui.View
---@return boolean
local function byFlatIndex(a, b)
	return (a.flat_index or 0) < (b.flat_index or 0)
end

---Step every animating view, then recompose each affected subtree once and run completions.
---@private
---@param dt number
function Screen:stepAnimations(dt)
	local animating = self.animating
	if next(animating) == nil then
		return
	end
	-- Completions may start or stop animations, so iterate a snapshot. Tree order makes
	-- completion order deterministic and lets a recomposed ancestor cover its descendants.
	local views, kinds = self.animation_views, self.animation_kinds
	local count = 0
	for view in pairs(animating) do
		count = count + 1
		views[count] = view
	end
	table.sort(views, byFlatIndex)

	local completions ---@type any[]?
	for i = 1, count do
		kinds[i], completions = views[i]:stepAnimations(dt, completions)
	end

	local flat = not self.dirty
	local geometry_end, any_end = 0, 0
	for i = 1, count do
		local view, kind = views[i], kinds[i]
		local index = flat and view.flat_index or math.huge
		if kind == Animation.GEOMETRY and index > geometry_end then
			view:composeSubtree()
			if flat then
				geometry_end = view.flat_subtree_end
				any_end = math.max(any_end, geometry_end)
			end
		elseif kind == Animation.OPACITY and index > any_end then
			view:composeSubtree(true)
			if flat then
				any_end = view.flat_subtree_end
			end
		end
	end

	Animation.runCompletions(completions)
	for i = 1, count do
		local view = views[i]
		views[i] = nil
		view:checkExpired()
		if not view:isAnimating() then
			animating[view] = nil
		end
	end
end

---Override for screen-level semantic actions. Views run first.
---@param inputs gui.Inputs
function Screen:onHandleInputs(inputs) end

---Internal semantic-input dispatch. ScreenManager controls which Screens run it.
---@private
---@param inputs gui.Inputs
function Screen:handleInputs(inputs)
	self:flush()
	local views = self.input_views
	for i = #views, 1, -1 do
		local view = views[i]
		if not view.detached and view.cull_mask == 0
			and view.effective_visible and view.effective_enabled and view.present
			and not inputs:isBlockedByFocusScope(view)
		then
			view:onHandleInputs(inputs)
		end
	end
	-- A focus scope in another screen (a modal in the overlay) owns the actions.
	local scope = inputs.focus_scopes[#inputs.focus_scopes]
	if not scope or scope.root.screen == self then
		self:onHandleInputs(inputs)
	end
end

---@param dt number
function Screen:update(dt)
	self:flush()
	-- Animations settle first so view update code always observes this frame's visual state.
	self:stepAnimations(dt)
	local views = self.update_views
	for i = 1, #views do
		local view = views[i]
		if not view.detached and view.effective_visible then
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
	local i = #views
	while i >= 1 do
		local view = views[i]
		if not view.effective_visible or not view.present then
			-- Visibility and presence are inherited: jump over the whole hidden subtree.
			local top = view ---@type gui.View
			local parent = top.parent ---@type gui.View?
			while parent and not (parent.effective_visible and parent.present) do
				top = parent
				parent = top.parent
			end
			i = top.flat_index - 1
		else
			if not view.detached and view.cull_mask == 0 and view.effective_enabled then
				inputs:processView(view)
			end
			i = i - 1
		end
	end
end

return Screen
