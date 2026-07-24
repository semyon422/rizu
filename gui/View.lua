local IInputHandler = require("gui.input.IInputHandler")
local Easing = require("gui.anim.Easing")

---@alias gui.Color [number, number, number, number]

---@class gui.Transform
---@field target string
---@field from number
---@field to number
---@field start number
---@field duration number
---@field easing gui.anim.Easing
---@field on_complete (fun(view: gui.View))?

---@class gui.View : gui.IInputHandler
---@operator call: gui.View
---@field parent gui.View?
---@field children gui.View[]
---@field screen gui.Screen?
---@field debug_name string?
---
---Authored layout inputs (§2.1). Layout owns resolution; never writes these.
---@field anchor_min {[1]: number, [2]: number}
---@field anchor_max {[1]: number, [2]: number}
---@field offset_min {[1]: number, [2]: number}
---@field offset_max {[1]: number, [2]: number}
---@field size_mode_x "fixed"|"fill"
---@field size_mode_y "fixed"|"fill"
---
---Transient arranged output (§2.1, §5). Written by the parent's strategy,
---cleared every relayout. When present, resolution uses it directly.
---@field arranged {[1]: number, [2]: number, [3]: number, [4]: number}?
---
---Behavior/state flags (§2.1).
---@field arrange_strategy gui.ArrangeStrategy?
---@field layout_ignore boolean
---@field align_self ("fill"|"start"|"center"|"end")?
---@field align_x number?
---@field align_y number?
---@field clip boolean
---@field visible boolean
---@field enabled boolean
---@field detached boolean
---@field loaded boolean
---
---Resolved rect (§2.1). Written only by layout; read-only everywhere else.
---@field x number
---@field y number
---@field width number
---@field height number
---
---Visual channel (§2.1). Never read or written by layout.
---@field offset_x number
---@field offset_y number
---@field pivot {[1]: number, [2]: number}
---@field rotation number
---@field scale_x number
---@field scale_y number
---@field opacity number
---
---Animation state (§11).
---@field private transforms {[string]: gui.Transform}
---@field expired boolean
---@field private animation_time number
---@field private transform_start number?
---@field private layout_initialized boolean
---
---Cached transforms and flattened traversal data (§2.1, §6.1).
---@field private transform love.Transform
---@field world_transform love.Transform
---@field effective_opacity number
---@field effective_visible boolean
---@field effective_enabled boolean
---@field present boolean
---@field flat_index integer?
---@field flat_subtree_end integer?
---
---Compose-time scale, applied to `scale_x`/`scale_y` in `compose()`.
---Set on screen roots by the Screen (the root's local transform bakes in
---`ui_scale`, §7.4); always 1 for non-roots.
---@field package root_scale number
---@field focused boolean
---@field mouse_over boolean
---@field pressed boolean
---@field handles_mouse_input boolean
---@field handles_keyboard_input boolean
local View = IInputHandler + {}

local transform_targets = {
	offset_x = true,
	offset_y = true,
	pivot_x = true,
	pivot_y = true,
	rotation = true,
	scale_x = true,
	scale_y = true,
	opacity = true,
}

---@param self gui.View
---@param target string
---@return number
local function getTransformValue(self, target)
	if target == "pivot_x" then return self.pivot[1] end
	if target == "pivot_y" then return self.pivot[2] end
	return self[target]
end

local function assertFinite(value, name)
	assert(type(value) == "number" and value == value and math.abs(value) < math.huge,
		("%s must be a finite number"):format(name))
end

---@param self gui.View
---@param target string
---@param value number
local function setTransformValue(self, target, value)
	if target == "pivot_x" then
		self.pivot = {value, self.pivot[2]}
	elseif target == "pivot_y" then
		self.pivot = {self.pivot[1], value}
	elseif target == "opacity" then
		self.opacity = math.max(0, math.min(1, value))
	else
		self[target] = value ---@diagnostic disable-line
	end
end

function View:new()
	self.parent = nil
	self.screen = nil
	self.debug_name = nil
	---@type gui.View[]
	self.children = {}

	self.anchor_min = {0, 0}
	self.anchor_max = {0, 0}
	self.offset_min = {0, 0}
	self.offset_max = {0, 0}
	self.size_mode_x = "fixed"
	self.size_mode_y = "fixed"

	self.arranged = nil
	self.arrange_strategy = nil
	self.layout_ignore = false
	self.align_self = nil
	self.align_x = nil
	self.align_y = nil
	self.clip = false

	self.x = 0
	self.y = 0
	self.width = 0
	self.height = 0

	self.offset_x = 0
	self.offset_y = 0
	self.pivot = {0, 0}
	self.rotation = 0
	self.scale_x = 1
	self.scale_y = 1
	self.opacity = 1

	---@type {[string]: gui.Transform}
	self.transforms = {}
	self.expired = false
	self.animation_time = 0
	self.transform_start = nil
	self.layout_initialized = false

	self.transform = love.math.newTransform()
	self.world_transform = love.math.newTransform()

	self.focused = false
	self.mouse_over = false
	self.pressed = false
	self.handles_mouse_input = false
	self.handles_keyboard_input = false
	self.visible = true
	self.enabled = true
	self.detached = false
	self.loaded = false
	self.effective_visible = true
	self.effective_enabled = true
	self.effective_opacity = 1
	self.present = true
end

---@generic T: gui.View
---@param child T
---@return T
function View:add(child)
	if child == self then
		error("cannot add a view to itself")
	end

	local ancestor = self.parent
	while ancestor do
		if ancestor == child then
			error("cannot add an ancestor view as a child (cycle)")
		end
		ancestor = ancestor.parent
	end

	if child.parent then
		child.parent:remove(child)
	end

	child.parent = self
	child:setDetached(false)
	child:setScreen(self.screen)
	table.insert(self.children, child)
	if self.screen then
		if self.screen.loaded then
			child:loadSubtree()
		end
		self.screen:invalidateLayout()
	end
	return child
end

---@param children gui.View[]
function View:addArray(children)
	for _, v in ipairs(children) do
		self:add(v)
	end
end

---@param child gui.View
function View:remove(child)
	for i, c in ipairs(self.children) do
		if c == child then
			local screen = self.screen
			child:setDetached(true)
			if screen and screen.inputs then
				screen.inputs:clearSubtree(child)
			end
			if child.loaded then
				child:unloadSubtree()
			end
			table.remove(self.children, i)
			child.parent = nil
			child:setScreen(nil)
			if screen then
				screen:invalidateLayout()
			end
			return
		end
	end

	error("cannot remove a view that is not a child")
end

---@param screen gui.Screen?
function View:setScreen(screen)
	self.screen = screen
	for i = 1, #self.children do
		self.children[i]:setScreen(screen)
	end
end

---@param detached boolean
function View:setDetached(detached)
	self.detached = detached
	for i = 1, #self.children do
		self.children[i]:setDetached(detached)
	end
end

---Override for resource setup. Geometry is not guaranteed here.
function View:load() end

---Override for resource teardown.
function View:unload() end

---@package
function View:loadSubtree()
	if not self.loaded then
		self:load()
		self.loaded = true
	end
	for i = 1, #self.children do
		self.children[i]:loadSubtree()
	end
end

---@package
function View:unloadSubtree()
	for i = #self.children, 1, -1 do
		self.children[i]:unloadSubtree()
	end
	if self.loaded then
		self:unload()
		self.loaded = false
	end
end

---Override for size-dependent resource and geometry updates.
---@param old_x number
---@param old_y number
---@param old_width number
---@param old_height number
function View:onLayoutChanged(old_x, old_y, old_width, old_height) end

function View:invalidate()
	if self.screen then
		self.screen:invalidateLayout()
	end
end

---@param strategy gui.ArrangeStrategy?
---@return gui.View
function View:setArrangeStrategy(strategy)
	assert(strategy == nil or type(strategy.arrange) == "function", "arrange strategy must provide arrange(container)")
	self.arrange_strategy = strategy
	self:invalidate()
	return self
end

---@param ignored boolean
---@return gui.View
function View:setLayoutIgnore(ignored)
	assert(type(ignored) == "boolean", "layout_ignore must be boolean")
	self.layout_ignore = ignored
	self:invalidate()
	return self
end

---@param clip boolean
---@return gui.View
function View:setClip(clip)
	assert(type(clip) == "boolean", "clip must be boolean")
	self.clip = clip
	self:invalidate()
	return self
end

---@param visible boolean
---@return gui.View
function View:setVisible(visible)
	assert(type(visible) == "boolean", "visible must be boolean")
	self.visible = visible
	self:composeSubtree()
	if not visible and self.screen and self.screen.inputs then
		self.screen.inputs:clearSubtree(self)
	end
	return self
end

---@param enabled boolean
---@return gui.View
function View:setEnabled(enabled)
	assert(type(enabled) == "boolean", "enabled must be boolean")
	self.enabled = enabled
	self:composeSubtree()
	if not enabled and self.screen and self.screen.inputs then
		self.screen.inputs:clearSubtree(self)
	end
	return self
end

---@param x number
---@param y number
---@param width number
---@param height number
---@return gui.View
function View:anchorFixed(x, y, width, height)
	assertFinite(x, "x")
	assertFinite(y, "y")
	assertFinite(width, "width")
	assertFinite(height, "height")
	assert(width >= 0 and height >= 0, "size must be non-negative")
	self.anchor_min = {0, 0}
	self.anchor_max = {0, 0}
	self.offset_min = {x, y}
	self.offset_max = {x + width, y + height}
	self.size_mode_x = "fixed"
	self.size_mode_y = "fixed"
	self.align_x = nil
	self.align_y = nil
	self:invalidate()
	return self
end

---@param left number
---@param top number
---@param right number
---@param bottom number
---@return gui.View
function View:anchorFill(left, top, right, bottom)
	assertFinite(left, "left")
	assertFinite(top, "top")
	assertFinite(right, "right")
	assertFinite(bottom, "bottom")
	self.anchor_min = {0, 0}
	self.anchor_max = {1, 1}
	self.offset_min = {left, top}
	self.offset_max = {-right, -bottom}
	self.size_mode_x = "fill"
	self.size_mode_y = "fill"
	self.align_x = nil
	self.align_y = nil
	self:invalidate()
	return self
end

---@param min_x number
---@param min_y number
---@param max_x number
---@param max_y number
---@return gui.View
function View:anchorPercent(min_x, min_y, max_x, max_y)
	assertFinite(min_x, "min_x")
	assertFinite(min_y, "min_y")
	assertFinite(max_x, "max_x")
	assertFinite(max_y, "max_y")
	assert(min_x >= 0 and min_x <= max_x and max_x <= 1, "x anchors must satisfy 0 <= min <= max <= 1")
	assert(min_y >= 0 and min_y <= max_y and max_y <= 1, "y anchors must satisfy 0 <= min <= max <= 1")
	self.anchor_min = {min_x, min_y}
	self.anchor_max = {max_x, max_y}
	self.offset_min = {0, 0}
	self.offset_max = {0, 0}
	self.size_mode_x = min_x == max_x and "fixed" or "fill"
	self.size_mode_y = min_y == max_y and "fixed" or "fill"
	self.align_x = nil
	self.align_y = nil
	self:invalidate()
	return self
end

---@param align_x number
---@param align_y number
---@return gui.View
function View:setAlignment(align_x, align_y)
	assertFinite(align_x, "align_x")
	assertFinite(align_y, "align_y")
	assert(align_x >= 0 and align_x <= 1 and align_y >= 0 and align_y <= 1,
		"alignment must be between 0 and 1")
	local width = self.offset_max[1] - self.offset_min[1]
	local height = self.offset_max[2] - self.offset_min[2]
	self.anchor_min = {align_x, align_y}
	self.anchor_max = {align_x, align_y}
	self.offset_min = {-align_x * width, -align_y * height}
	self.offset_max = {(1 - align_x) * width, (1 - align_y) * height}
	self.size_mode_x = "fixed"
	self.size_mode_y = "fixed"
	self.align_x = align_x
	self.align_y = align_y
	self:invalidate()
	return self
end

---@param x number
---@param y number
---@return gui.View
function View:setPosition(x, y)
	assert(self.size_mode_x == "fixed" and self.size_mode_y == "fixed",
		"setPosition cannot be used on a fill axis")
	assertFinite(x, "x")
	assertFinite(y, "y")
	local width = self.offset_max[1] - self.offset_min[1]
	local height = self.offset_max[2] - self.offset_min[2]
	self.offset_min = {x, y}
	self.offset_max = {x + width, y + height}
	self.align_x = nil
	self.align_y = nil
	self:invalidate()
	return self
end

---@param width number
---@param height number
---@return gui.View
function View:setSize(width, height)
	assert(self.size_mode_x == "fixed" and self.size_mode_y == "fixed",
		"setSize cannot be used on a fill axis")
	assertFinite(width, "width")
	assertFinite(height, "height")
	assert(width >= 0 and height >= 0, "size must be non-negative")
	local min_x = self.align_x and -self.align_x * width or self.offset_min[1]
	local min_y = self.align_y and -self.align_y * height or self.offset_min[2]
	self.offset_min = {min_x, min_y}
	self.offset_max = {min_x + width, min_y + height}
	self:invalidate()
	return self
end

---Set or clear an instance-level update override. Class-level overrides are
---discovered automatically during flattening.
---@param callback (fun(self: gui.View, dt: number))?
function View:setUpdate(callback)
	assert(callback == nil or type(callback) == "function", "update callback must be a function or nil")
	rawset(self, "update", callback)
	self:invalidate()
end

---Set or clear an instance-level draw override. Class-level overrides are
---discovered automatically during flattening.
---@param callback (fun(self: gui.View))?
function View:setDraw(callback)
	assert(callback == nil or type(callback) == "function", "draw callback must be a function or nil")
	rawset(self, "draw", callback)
	self:invalidate()
end

---Recursively detach every descendant. After this call `self.children` is empty
---and no view in the former subtree retains a parent reference. `self` stays
---attached to its own parent.
---@private
function View:clear()
	for i = #self.children, 1, -1 do
		local child = self.children[i]
		child:clear()
		self:remove(child)
	end
end

---Rebuild the tree's resolved rects and transforms top-down.
---Call on the root after authored inputs or the root size change.
---@param root_scale number?  ui_scale, only meaningful when called on a screen root; defaults to 1
function View:relayout(root_scale)
	root_scale = root_scale or 1
	local initialized = self.layout_initialized
	local old_x, old_y = self.x, self.y
	local old_width, old_height = self.width, self.height
	if self.parent then
		self:resolve(self.parent)
		self:applyLayoutTransition(old_x, old_y, old_width, old_height)
	end
	self.layout_initialized = true
	self:compose(root_scale)
	if not initialized or old_x ~= self.x or old_y ~= self.y
		or old_width ~= self.width or old_height ~= self.height
	then
		self:onLayoutChanged(old_x, old_y, old_width, old_height)
	end
	self:arrangeChildren()
	for _, child in ipairs(self.children) do
		child:relayout()
	end
end

---@private
---@param parent gui.View
function View:resolve(parent)
	local arranged = self.arranged
	if arranged then
		self.x = arranged[1]
		self.y = arranged[2]
		self.width = math.max(0, arranged[3])
		self.height = math.max(0, arranged[4])
		return
	end
	local pw, ph = parent.width, parent.height
	local anchor_min = self.anchor_min
	local anchor_max = self.anchor_max
	local offset_min = self.offset_min
	local offset_max = self.offset_max
	self.x = anchor_min[1] * pw + offset_min[1]
	self.y = anchor_min[2] * ph + offset_min[2]
	self.width = math.max(0, (anchor_max[1] - anchor_min[1]) * pw + (offset_max[1] - offset_min[1]))
	self.height = math.max(0, (anchor_max[2] - anchor_min[2]) * ph + (offset_max[2] - offset_min[2]))
end

---@private
---@param old_x number
---@param old_y number
---@param old_width number
---@param old_height number
function View:applyLayoutTransition(old_x, old_y, old_width, old_height)
	local strategy = self.parent and self.parent.arrange_strategy
	local transition = strategy and strategy.layout_transition
	if not self.layout_initialized or not transition or transition.duration == 0 then
		return
	end
	if old_x == self.x and old_y == self.y and old_width == self.width and old_height == self.height then
		return
	end

	local start = self.animation_time
	local duration = transition.duration
	local easing = transition.easing or "OutQuint"
	if old_x ~= self.x then
		self.offset_x = self.offset_x + old_x - self.x
		self:transformToAt("offset_x", 0, duration, easing, start)
	end
	if old_y ~= self.y then
		self.offset_y = self.offset_y + old_y - self.y
		self:transformToAt("offset_y", 0, duration, easing, start)
	end
	if old_width ~= self.width and old_width > 0 and self.width > 0 then
		self.scale_x = old_width / self.width
		self:transformToAt("scale_x", 1, duration, easing, start)
	end
	if old_height ~= self.height and old_height > 0 and self.height > 0 then
		self.scale_y = old_height / self.height
		self:transformToAt("scale_y", 1, duration, easing, start)
	end
end

---Clear every child's `arranged`, then run the strategy if attached (§5).
---@private
function View:arrangeChildren()
	local children = self.children
	for i = 1, #children do
		children[i].arranged = nil
	end
	local strategy = self.arrange_strategy
	if strategy then
		strategy:arrange(self)
	end
end

---@private
---@param root_scale number  ui_scale baked into the local transform; 1 for non-roots
function View:compose(root_scale)
	local sx = self.scale_x * root_scale
	local sy = self.scale_y * root_scale
	local w = self.width
	local h = self.height
	local px = self.pivot[1] * w
	local py = self.pivot[2] * h
	self.transform:setTransformation(
		(self.x + self.offset_x + px) * root_scale,
		(self.y + self.offset_y + py) * root_scale,
		self.rotation,
		sx, sy,
		px, py
	)
	local world_transform = self.world_transform
	world_transform:reset()
	if self.parent then
		world_transform:apply(self.parent.world_transform)
		self.effective_opacity = self.parent.effective_opacity * self.opacity
		self.effective_visible = self.parent.effective_visible and self.visible
		self.effective_enabled = self.parent.effective_enabled and self.enabled
	else
		self.effective_opacity = self.opacity
		self.effective_visible = self.visible
		self.effective_enabled = self.enabled
	end
	world_transform:apply(self.transform)
	self.present = self.effective_opacity > 0.001 and self.scale_x ~= 0 and self.scale_y ~= 0
end

local function composeRecursive(view, root_scale)
	view:compose(root_scale)
	for i = 1, #view.children do
		composeRecursive(view.children[i], 1)
	end
end

---Recompose this view and its descendants without running layout.
function View:composeSubtree()
	local screen = self.screen
	local first = self.flat_index
	local last = self.flat_subtree_end
	if screen and not screen.dirty and first and last then
		for i = first, last do
			local view = screen.views[i]
			view:compose(view.parent and 1 or screen.ui_scale)
		end
		return
	end

	composeRecursive(self, self.parent and 1 or (screen and screen.ui_scale or 1))
end

---@param target string
---@param to number
---@param duration number
---@param easing gui.anim.EasingName|gui.anim.Easing?
---@param on_complete (fun(view: gui.View))?
---@return gui.View
function View:transformTo(target, to, duration, easing, on_complete)
	assert(transform_targets[target], ("invalid transform target: %s"):format(tostring(target)))
	assert(type(to) == "number" and to == to and math.abs(to) < math.huge, "transform target value must be finite")
	assert(type(duration) == "number" and duration >= 0 and duration < math.huge, "transform duration must be finite and non-negative")
	assert(on_complete == nil or type(on_complete) == "function", "transform completion must be a function or nil")
	local start = self.transform_start or self.animation_time
	local transform = {
		target = target,
		from = getTransformValue(self, target),
		to = to,
		start = start,
		duration = duration,
		easing = Easing.resolve(easing),
		on_complete = on_complete,
	}
	self.transforms[target] = transform
	if duration == 0 and start <= self.animation_time then
		setTransformValue(self, target, to)
		self.transforms[target] = nil
		self:composeSubtree()
		if on_complete then on_complete(self) end
		self:checkExpired()
	end
	return self
end

---@param dt number
function View:stepTransforms(dt)
	assert(type(dt) == "number" and dt >= 0, "animation dt must be non-negative")
	self.animation_time = self.animation_time + dt
	if self.transform_start and self.animation_time >= self.transform_start then
		self.transform_start = nil
	end
	local changed = false
	local completions = {} ---@type (fun(view: gui.View))[]
	for target, transform in pairs(self.transforms) do
		if self.animation_time >= transform.start then
			local progress ---@type number
			if transform.duration == 0 then
				progress = 1
			else
				progress = math.min(1, (self.animation_time - transform.start) / transform.duration)
			end
			setTransformValue(self, target, transform.from + (transform.to - transform.from) * transform.easing(progress))
			changed = true
			if progress >= 1 then
				setTransformValue(self, target, transform.to)
				self.transforms[target] = nil
				if transform.on_complete then completions[#completions + 1] = transform.on_complete end
			end
		end
	end
	if changed then self:composeSubtree() end
	for i = 1, #completions do completions[i](self) end
	self:checkExpired()
end

---@return boolean
function View:hasTransforms()
	return next(self.transforms) ~= nil
end

---@param target string?
---@return gui.View
function View:finishTransforms(target)
	if target ~= nil then assert(transform_targets[target], ("invalid transform target: %s"):format(tostring(target))) end
	local completions = {} ---@type (fun(view: gui.View))[]
	local changed = false
	for transform_target, transform in pairs(self.transforms) do
		if target == nil or target == transform_target then
			setTransformValue(self, transform_target, transform.to)
			self.transforms[transform_target] = nil
			changed = true
			if transform.on_complete then completions[#completions + 1] = transform.on_complete end
		end
	end
	if changed then self:composeSubtree() end
	for i = 1, #completions do completions[i](self) end
	self:checkExpired()
	return self
end

---@param target string?
---@return gui.View
function View:clearTransforms(target)
	if target ~= nil then
		assert(transform_targets[target], ("invalid transform target: %s"):format(tostring(target)))
		self.transforms[target] = nil
	else
		self.transforms = {}
	end
	self:checkExpired()
	return self
end

---@param duration number
---@return gui.View
function View:delay(duration)
	assert(type(duration) == "number" and duration >= 0 and duration < math.huge, "delay must be finite and non-negative")
	local latest = self.animation_time
	for _, transform in pairs(self.transforms) do
		latest = math.max(latest, transform.start + transform.duration)
	end
	self.transform_start = latest + duration
	return self
end

---@param target string
---@param to number
---@param duration number
---@param easing gui.anim.EasingName|gui.anim.Easing?
---@param start number
function View:transformToAt(target, to, duration, easing, start)
	local saved = self.transform_start
	self.transform_start = start
	self:transformTo(target, to, duration, easing)
	self.transform_start = saved
end

---@param alpha number
---@param duration number
---@param easing gui.anim.EasingName|gui.anim.Easing?
---@return gui.View
function View:fadeTo(alpha, duration, easing)
	assert(alpha >= 0 and alpha <= 1, "opacity must be between 0 and 1")
	return self:transformTo("opacity", alpha, duration, easing)
end

---@param duration number
---@param easing gui.anim.EasingName|gui.anim.Easing?
---@return gui.View
function View:fadeIn(duration, easing)
	return self:fadeTo(1, duration, easing or "OutQuint")
end

---@param duration number
---@param easing gui.anim.EasingName|gui.anim.Easing?
---@return gui.View
function View:fadeOut(duration, easing)
	return self:fadeTo(0, duration, easing or "OutQuad")
end

---@param x number
---@param y number
---@param duration number
---@param easing gui.anim.EasingName|gui.anim.Easing?
---@return gui.View
function View:moveTo(x, y, duration, easing)
	local start = self.transform_start or self.animation_time
	self:transformToAt("offset_x", x, duration, easing, start)
	self:transformToAt("offset_y", y, duration, easing, start)
	return self
end

---@param x number
---@param duration number
---@param easing gui.anim.EasingName|gui.anim.Easing?
---@return gui.View
function View:moveToX(x, duration, easing)
	return self:transformTo("offset_x", x, duration, easing)
end

---@param y number
---@param duration number
---@param easing gui.anim.EasingName|gui.anim.Easing?
---@return gui.View
function View:moveToY(y, duration, easing)
	return self:transformTo("offset_y", y, duration, easing)
end

---@param scale_x number
---@param scale_y number
---@param duration number
---@param easing gui.anim.EasingName|gui.anim.Easing?
---@return gui.View
function View:scaleTo(scale_x, scale_y, duration, easing)
	local start = self.transform_start or self.animation_time
	self:transformToAt("scale_x", scale_x, duration, easing, start)
	self:transformToAt("scale_y", scale_y, duration, easing, start)
	return self
end

---@param pivot_x number
---@param pivot_y number
---@param duration number
---@param easing gui.anim.EasingName|gui.anim.Easing?
---@return gui.View
function View:pivotTo(pivot_x, pivot_y, duration, easing)
	local start = self.transform_start or self.animation_time
	self:transformToAt("pivot_x", pivot_x, duration, easing, start)
	self:transformToAt("pivot_y", pivot_y, duration, easing, start)
	return self
end

---@param rotation number
---@param duration number
---@param easing gui.anim.EasingName|gui.anim.Easing?
---@return gui.View
function View:rotateTo(rotation, duration, easing)
	return self:transformTo("rotation", rotation, duration, easing)
end

---@return gui.View
function View:expire()
	self.expired = true
	self:checkExpired()
	return self
end

---@private
function View:checkExpired()
	if self.expired and not self:hasTransforms() and self.screen then
		self.screen:queueExpire(self)
	end
end

---@param x number
---@param y number
---@return gui.View
function View:setOffset(x, y)
	self.offset_x = x
	self.offset_y = y
	self:composeSubtree()
	return self
end

---@param rotation number
---@return gui.View
function View:setRotation(rotation)
	self.rotation = rotation
	self:composeSubtree()
	return self
end

---@param scale_x number
---@param scale_y number
---@return gui.View
function View:setScale(scale_x, scale_y)
	self.scale_x = scale_x
	self.scale_y = scale_y
	self:composeSubtree()
	return self
end

---@param pivot_x number
---@param pivot_y number
---@return gui.View
function View:setPivot(pivot_x, pivot_y)
	self.pivot = {pivot_x, pivot_y}
	self:composeSubtree()
	return self
end

---@param opacity number
---@return gui.View
function View:setOpacity(opacity)
	assert(opacity >= 0 and opacity <= 1, "opacity must be between 0 and 1")
	self.opacity = opacity
	self:composeSubtree()
	return self
end

---@return number x
---@return number y
function View:getWorldPosition()
	return self.world_transform:transformPoint(0, 0)
end

---Tests whether a window-space point lies within this view's transformed rect.
---Override for non-rectangular hit regions.
---@param screen_x number
---@param screen_y number
---@return boolean
function View:isMouseOver(screen_x, screen_y)
	local x, y = self.world_transform:inverseTransformPoint(screen_x, screen_y)
	return x >= 0 and x <= self.width and y >= 0 and y <= self.height
end

---@param inputs gui.Inputs
function View:acceptInputs(inputs)
	for i = #self.children, 1, -1 do
		self.children[i]:acceptInputs(inputs)
	end
	inputs:processView(self)
end

---Override. Draws in local space: [0, width] x [0, height].
function View:draw() end

---Override. Called every frame with the frame delta.
---@param dt number
function View:update(dt) end

return View
