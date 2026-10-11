local IInputHandler = require("gui.input.IInputHandler")
local Easing = require("gui.anim.Easing")
local Animation = require("gui.view.Animation")

---@alias gui.Color [number, number, number, number]

---Compensation at `start`; it decays to none over `duration`.
---@class gui.View.LayoutTween
---@field dx number
---@field dy number
---@field sx number
---@field sy number
---@field start number
---@field duration number
---@field easing gui.anim.Easing

---@class gui.View : gui.IInputHandler
---@operator call: gui.View
---@field parent gui.View?
---@field getBaseline? fun(self: gui.View): number? Distance from the top to the text baseline; lets baseline-aligned containers line children up.
---@field afterLayout? fun(self: gui.View) Called after each screen rebuild, once every view is resolved and flattened.
---@field children gui.View[]
---@field screen gui.Screen?
---@field pending_unload_screen gui.Screen?
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
---Transient arranged output. Written by the parent's `arrange`, cleared every
---relayout. When present, resolution uses it directly.
---@field arranged {[1]: number, [2]: number, [3]: number, [4]: number}?
---
---Behavior/state flags (§2.1).
---@field arrange? fun(self: gui.View) Layout containers define this to write each child's `arranged` rect.
---@field layout_transition gui.layout.LayoutTransition? Glide for children whose rect this view's layout changes.
---@field layout_ignore boolean
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
---Animation state, owned by gui.view.Animation.
---@field transforms {[string]: gui.Transform} Running transforms by target
---@field pending_transforms gui.Transform[]? Delayed transforms in start order
---@field animation_time number View clock; advances only while the view is animating on a screen
---@field expired boolean
---@field private layout_initialized boolean
---
---Layout transition compensation: a private visual delta that makes a rect change glide.
---`compose()` combines it with the visual channel; it never writes `offset_*`/`scale_*`.
---@field private layout_dx number
---@field private layout_dy number
---@field private layout_sx number
---@field private layout_sy number
---@field private layout_tween gui.View.LayoutTween?
---@field private layout_parent gui.View? Parent of the last resolution
---@field private layout_width number Size at the last resolution
---@field private layout_height number
---@field private layout_resized boolean This pass resized the view because the window or an ancestor resized
---
---Cached transforms and flattened traversal data (§2.1, §6.1).
---@field private transform love.Transform
---@field world_transform love.Transform
---@field effective_opacity number
---@field render_opacity number Opacity relative to the active composite boundary
---@field is_composite boolean
---@field clip_rect {[1]: number, [2]: number, [3]: number, [4]: number}?
---@field effective_visible boolean
---@field effective_enabled boolean
---@field present boolean
---@field cull_mask integer Bitmask of geometry-based cull causes
---@field viewport_culls {[gui.ScrollView]: true}?
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
---@field drag_axis "horizontal"|"vertical"? Preferred drag direction for pointer-capture arbitration
---@field handles_keyboard_input boolean
---@field keyboard_input_fallback boolean Dispatch keyboard events after ordinary requesters
local View = IInputHandler + {}

View.CULL_CLIP_EMPTY = 1
View.CULL_VIEWPORT = 2

local function assertFinite(value, name)
	assert(type(value) == "number" and value == value and math.abs(value) < math.huge,
		("%s must be a finite number"):format(name))
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
	self.layout_transition = nil
	self.layout_ignore = false
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
	self.pending_transforms = nil
	self.expired = false
	self.animation_time = 0
	self.layout_initialized = false
	self.layout_dx = 0
	self.layout_dy = 0
	self.layout_sx = 1
	self.layout_sy = 1
	self.layout_tween = nil
	self.layout_parent = nil
	self.layout_width = 0
	self.layout_height = 0
	self.layout_resized = false

	self.transform = love.math.newTransform()
	self.world_transform = love.math.newTransform()

	self.focused = false
	self.mouse_over = false
	self.pressed = false
	self.handles_mouse_input = false
	self.drag_axis = nil
	self.handles_keyboard_input = false
	self.keyboard_input_fallback = false
	self.visible = true
	self.enabled = true
	self.detached = false
	self.loaded = false
	self.pending_unload_screen = nil
	self.effective_visible = true
	self.effective_enabled = true
	self.effective_opacity = 1
	self.render_opacity = 1
	self.is_composite = false
	self.clip_rect = nil
	self.present = true
	self.cull_mask = 0
	self.viewport_culls = nil
end

---@param parent gui.View
---@param child gui.View
local function assertCanAdopt(parent, child)
	if child == parent then
		error("cannot add a view to itself")
	end

	local ancestor = parent.parent
	while ancestor do
		if ancestor == child then
			error("cannot add an ancestor view as a child (cycle)")
		end
		ancestor = ancestor.parent
	end
end

---@param index any
---@param max_index integer
local function assertInsertIndex(index, max_index)
	assert(type(index) == "number" and index == math.floor(index), "index must be an integer")
	assert(index >= 1 and index <= max_index, "index is out of range")
end

---@generic T: gui.View
---@param child T
---@return T
function View:add(child)
	---@cast child gui.View
	-- Not self:insert: subclasses override insert with their own bookkeeping.
	return View.insert(self, #self.children + (child.parent == self and 0 or 1), child)
end

---@generic T: gui.View
---@param index integer
---@param child T
---@return T
function View:insert(index, child)
	local max_index = #self.children + (child.parent == self and 0 or 1)
	assertInsertIndex(index, max_index)
	assertCanAdopt(self, child)
	---@cast child gui.View

	if child.parent == self then
		self:move(child, index)
		return child
	end
	if child.parent then
		child.parent:remove(child)
	end

	local screen = self.screen
	local pending_screen = child.pending_unload_screen
	if pending_screen then
		if pending_screen == screen then
			pending_screen:cancelUnload(child)
		else
			pending_screen:flushPendingUnload(child)
		end
	end

	child.parent = self
	child:setDetached(false)
	child:setScreen(screen)
	table.insert(self.children, index, child)
	if screen then
		if screen.loaded then
			child:loadSubtree()
		end
		screen:invalidateLayout()
	end
	return child
end

---@param child gui.View
---@param index integer
function View:move(child, index)
	assertInsertIndex(index, #self.children)
	local old_index ---@type integer?
	for i = 1, #self.children do
		if self.children[i] == child then
			old_index = i
			break
		end
	end
	assert(old_index, "cannot move a view that is not a child")

	table.remove(self.children, old_index)
	table.insert(self.children, index, child)
	self:invalidate()
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
			table.remove(self.children, i)
			child.parent = nil
			child:setScreen(nil)
			if screen then
				screen:queueUnload(child)
				screen:invalidateLayout()
			else
				child:unloadSubtree()
			end
			return
		end
	end

	error("cannot remove a view that is not a child")
end

---@param screen gui.Screen?
function View:setScreen(screen)
	local old_screen = self.screen
	if old_screen ~= screen and self:isAnimating() then
		if old_screen then old_screen:untrackAnimation(self) end
		if screen then screen:trackAnimation(self) end
	end
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

function View:loadSubtree()
	if not self.loaded then
		self:load()
		self.loaded = true
	end
	for i = 1, #self.children do
		self.children[i]:loadSubtree()
	end
end

function View:unloadSubtree()
	for i = #self.children, 1, -1 do
		self.children[i]:unloadSubtree()
	end
	if self.loaded then
		self:unload()
		self.loaded = false
	end
	-- The next attach is a first resolution again: onLayoutChanged fires and nothing glides.
	self.layout_initialized = false
	self.layout_tween = nil
	self.layout_dx, self.layout_dy, self.layout_sx, self.layout_sy = 0, 0, 1, 1
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

---@param ignored boolean
---@return gui.View
function View:setLayoutIgnore(ignored)
	assert(type(ignored) == "boolean", "layout_ignore must be boolean")
	if self.layout_ignore == ignored then return self end
	self.layout_ignore = ignored
	self:invalidate()
	return self
end

---@param clip boolean
---@return gui.View
function View:setClip(clip)
	assert(type(clip) == "boolean", "clip must be boolean")
	if self.clip == clip then return self end
	self.clip = clip
	self:invalidate()
	return self
end

---@param visible boolean
---@return gui.View
function View:setVisible(visible)
	assert(type(visible) == "boolean", "visible must be boolean")
	if self.visible == visible then return self end
	self.visible = visible
	self:composeSubtree(true)
	return self
end

---@param enabled boolean
---@return gui.View
function View:setEnabled(enabled)
	assert(type(enabled) == "boolean", "enabled must be boolean")
	if self.enabled == enabled then return self end
	self.enabled = enabled
	self:composeSubtree(true)
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

---@param left number
---@param right number
---@return gui.View
function View:fillWidth(left, right)
	assertFinite(left, "left")
	assertFinite(right, "right")
	self.anchor_min = {0, self.anchor_min[2]}
	self.anchor_max = {1, self.anchor_max[2]}
	self.offset_min = {left, self.offset_min[2]}
	self.offset_max = {-right, self.offset_max[2]}
	self.size_mode_x = "fill"
	self.align_x = nil
	self:invalidate()
	return self
end

---@param top number
---@param bottom number
---@return gui.View
function View:fillHeight(top, bottom)
	assertFinite(top, "top")
	assertFinite(bottom, "bottom")
	self.anchor_min = {self.anchor_min[1], 0}
	self.anchor_max = {self.anchor_max[1], 1}
	self.offset_min = {self.offset_min[1], top}
	self.offset_max = {self.offset_max[1], -bottom}
	self.size_mode_y = "fill"
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
	local width, height = self:getAuthoredSize()
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

---@param align_x number
---@return gui.View
function View:setAlignmentX(align_x)
	assertFinite(align_x, "align_x")
	assert(align_x >= 0 and align_x <= 1, "alignment must be between 0 and 1")
	local width = self:getAuthoredWidth()
	self.anchor_min = {align_x, self.anchor_min[2]}
	self.anchor_max = {align_x, self.anchor_max[2]}
	self.offset_min = {-align_x * width, self.offset_min[2]}
	self.offset_max = {(1 - align_x) * width, self.offset_max[2]}
	self.size_mode_x = "fixed"
	self.align_x = align_x
	self:invalidate()
	return self
end

---@param align_y number
---@return gui.View
function View:setAlignmentY(align_y)
	assertFinite(align_y, "align_y")
	assert(align_y >= 0 and align_y <= 1, "alignment must be between 0 and 1")
	local height = self:getAuthoredHeight()
	self.anchor_min = {self.anchor_min[1], align_y}
	self.anchor_max = {self.anchor_max[1], align_y}
	self.offset_min = {self.offset_min[1], -align_y * height}
	self.offset_max = {self.offset_max[1], (1 - align_y) * height}
	self.size_mode_y = "fixed"
	self.align_y = align_y
	self:invalidate()
	return self
end

---Authored size: the rect's size before anchors and parent arrangement apply.
---@return number width
---@return number height
function View:getAuthoredSize()
	return self.offset_max[1] - self.offset_min[1], self.offset_max[2] - self.offset_min[2]
end

---@return number
function View:getAuthoredWidth()
	return self.offset_max[1] - self.offset_min[1]
end

---@return number
function View:getAuthoredHeight()
	return self.offset_max[2] - self.offset_min[2]
end

---@param x number
---@param y number
---@return gui.View
function View:setPosition(x, y)
	assert(self.size_mode_x == "fixed" and self.size_mode_y == "fixed",
		"setPosition cannot be used on a fill axis")
	assertFinite(x, "x")
	assertFinite(y, "y")
	local anchor = self.anchor_min
	if self.offset_min[1] == x and self.offset_min[2] == y and anchor[1] == 0 and anchor[2] == 0
		and not self.align_x and not self.align_y
	then
		return self
	end
	local width, height = self:getAuthoredSize()
	-- Position is relative to the parent's origin, whatever alignment came before.
	self.anchor_min = {0, 0}
	self.anchor_max = {0, 0}
	self.offset_min = {x, y}
	self.offset_max = {x + width, y + height}
	self.align_x = nil
	self.align_y = nil
	self:invalidate()
	return self
end

---Translate the authored rect relative to its current anchored position.
---Unlike setPosition, this preserves anchors and alignment and works on fill axes.
---@param x number
---@param y number
---@return gui.View
function View:addPosition(x, y)
	assertFinite(x, "x")
	assertFinite(y, "y")
	if x == 0 and y == 0 then return self end
	self.offset_min = {self.offset_min[1] + x, self.offset_min[2] + y}
	self.offset_max = {self.offset_max[1] + x, self.offset_max[2] + y}
	self:invalidate()
	return self
end

---@param width number
---@return gui.View
function View:setWidth(width)
	assert(self.size_mode_x == "fixed", "setWidth cannot be used on a fill axis")
	assertFinite(width, "width")
	assert(width >= 0, "size must be non-negative")
	local old_width = self:getAuthoredWidth()
	if old_width == width then return self end
	local min_x = self.align_x
		and self.offset_min[1] + self.align_x * old_width - self.align_x * width
		or self.offset_min[1]
	self.offset_min = {min_x, self.offset_min[2]}
	self.offset_max = {min_x + width, self.offset_max[2]}
	self:invalidate()
	return self
end

---@param height number
---@return gui.View
function View:setHeight(height)
	assert(self.size_mode_y == "fixed", "setHeight cannot be used on a fill axis")
	assertFinite(height, "height")
	assert(height >= 0, "size must be non-negative")
	local old_height = self:getAuthoredHeight()
	if old_height == height then return self end
	local min_y = self.align_y
		and self.offset_min[2] + self.align_y * old_height - self.align_y * height
		or self.offset_min[2]
	self.offset_min = {self.offset_min[1], min_y}
	self.offset_max = {self.offset_max[1], min_y + height}
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
	local old_width, old_height = self:getAuthoredSize()
	if old_width == width and old_height == height then return self end
	local min_x = self.align_x
		and self.offset_min[1] + self.align_x * old_width - self.align_x * width
		or self.offset_min[1]
	local min_y = self.align_y
		and self.offset_min[2] + self.align_y * old_height - self.align_y * height
		or self.offset_min[2]
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

---Remove every direct child. Each removed child keeps its own subtree, so it
---unloads as a unit and can be added again.
function View:clear()
	for i = #self.children, 1, -1 do
		self:remove(self.children[i])
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
	local parent = self.parent
	if parent then
		self:resolve(parent)
	end
	-- A resize the view chose itself (setSize, fitContent) still lets its children glide.
	self.layout_resized = (self.layout_width ~= self.width or self.layout_height ~= self.height)
		and (not parent or parent.layout_resized)
	self.layout_width, self.layout_height = self.width, self.height
	if parent and initialized and self.layout_parent == parent and not parent.layout_resized then
		self:applyLayoutTransition(old_x, old_y, old_width, old_height)
	end
	self.layout_parent = parent
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

---@param value number
---@return integer
local function round(value)
	return math.floor(value + 0.5)
end

---@private
---@param parent gui.View
function View:resolve(parent)
	local left, top, right, bottom = 0, 0, 0, 0
	local arranged = self.arranged
	if arranged then
		left = arranged[1]
		top = arranged[2]
		right = left + arranged[3]
		bottom = top + arranged[4]
	else
		local pw, ph = parent.width, parent.height
		local anchor_min = self.anchor_min
		local anchor_max = self.anchor_max
		local offset_min = self.offset_min
		local offset_max = self.offset_max
		left = anchor_min[1] * pw + offset_min[1]
		top = anchor_min[2] * ph + offset_min[2]
		right = anchor_max[1] * pw + offset_max[1]
		bottom = anchor_max[2] * ph + offset_max[2]
	end

	left, top = round(left), round(top)
	right, bottom = round(right), round(bottom)
	self.x = left
	self.y = top
	self.width = math.max(0, right - left)
	self.height = math.max(0, bottom - top)
end

---An ancestor that is scale-compensating already shows its whole subtree at the old size.
---@private
---@return boolean
function View:hasScalingAncestor()
	local ancestor = self.parent
	while ancestor do
		if ancestor.layout_sx ~= 1 or ancestor.layout_sy ~= 1 then
			return true
		end
		ancestor = ancestor.parent
	end
	return false
end

---Start or retarget the glide for a rect the parent's layout just changed.
---@private
---@param old_x number
---@param old_y number
---@param old_width number
---@param old_height number
function View:applyLayoutTransition(old_x, old_y, old_width, old_height)
	local transition = self.parent.layout_transition
	if not transition or transition.duration == 0 then
		return
	end
	local width, height = self.width, self.height
	if old_x == self.x and old_y == self.y and old_width == width and old_height == height then
		return
	end

	-- Compose with the compensation still in flight so the visual rect is continuous.
	local dx = self.layout_dx + old_x - self.x
	local dy = self.layout_dy + old_y - self.y
	local sx, sy = self.layout_sx, self.layout_sy
	if transition.scale_size and not self:hasScalingAncestor() then
		if old_width ~= width and old_width > 0 and width > 0 then
			sx = sx * old_width / width
			-- Scaling happens about the pivot; this keeps the old left edge.
			dx = dx + self.pivot[1] * (old_width - width)
		end
		if old_height ~= height and old_height > 0 and height > 0 then
			sy = sy * old_height / height
			dy = dy + self.pivot[2] * (old_height - height)
		end
	end
	self.layout_dx, self.layout_dy, self.layout_sx, self.layout_sy = dx, dy, sx, sy

	local tween = self.layout_tween or {}
	tween.dx, tween.dy, tween.sx, tween.sy = dx, dy, sx, sy
	tween.start = self.animation_time
	tween.duration = transition.duration
	tween.easing = Easing.resolve(transition.easing or "OutQuint")
	self.layout_tween = tween
	if self.screen then
		self.screen:trackAnimation(self)
	end
end

---Clear every child's `arranged`, then let a layout container arrange them.
---@private
function View:arrangeChildren()
	local children = self.children
	for i = 1, #children do
		children[i].arranged = nil
	end
	if self.arrange then
		self:arrange()
	end
end

---@param transform love.Transform
---@param width number
---@param height number
---@return number x
---@return number y
---@return number rect_width
---@return number rect_height
local function getAxisAlignedBounds(transform, width, height)
	local x0, y0 = transform:transformPoint(0, 0)
	local xx, yx = transform:transformPoint(width, 0)
	local xy, yy = transform:transformPoint(0, height)
	local epsilon = 1e-9
	assert(math.abs(xx - x0) <= epsilon or math.abs(yx - y0) <= epsilon,
		"clip view must have an axis-aligned world transform")
	assert(math.abs(xy - x0) <= epsilon or math.abs(yy - y0) <= epsilon,
		"clip view must have an axis-aligned world transform")
	local x1 = math.min(x0, xx, xy)
	local y1 = math.min(y0, yx, yy)
	local x2 = math.max(x0, xx, xy)
	local y2 = math.max(y0, yx, yy)
	return x1, y1, x2 - x1, y2 - y1
end

---@param view gui.View
local function composeClipRect(view)
	local parent_clip = view.parent and view.parent.clip_rect
	if not view.clip then
		if parent_clip then
			local rect = view.clip_rect or {0, 0, 0, 0}
			rect[1], rect[2], rect[3], rect[4] = parent_clip[1], parent_clip[2], parent_clip[3], parent_clip[4]
			view.clip_rect = rect
		else
			view.clip_rect = nil
		end
		return
	end

	local x, y, width, height = getAxisAlignedBounds(view.world_transform, view.width, view.height)
	if parent_clip then
		local right = math.min(x + width, parent_clip[1] + parent_clip[3])
		local bottom = math.min(y + height, parent_clip[2] + parent_clip[4])
		x = math.max(x, parent_clip[1])
		y = math.max(y, parent_clip[2])
		width = math.max(0, right - x)
		height = math.max(0, bottom - y)
	end
	local rect = view.clip_rect or {0, 0, 0, 0}
	rect[1], rect[2], rect[3], rect[4] = x, y, width, height
	view.clip_rect = rect
end

---@private
---@param root_scale number  ui_scale baked into the local transform; 1 for non-roots
---@param opacity_only boolean? Skip matrices and clip rects: only opacity, visibility or enabled changed
function View:compose(root_scale, opacity_only)
	local was_input_present = self.effective_visible and self.effective_enabled
		and self.present and self.cull_mask == 0
	if not opacity_only then
		self:composeGeometry(root_scale)
	end
	local parent = self.parent
	if parent then
		self.effective_opacity = parent.effective_opacity * self.opacity
		if parent.is_composite then
			self.render_opacity = self.opacity
		else
			self.render_opacity = parent.render_opacity * self.opacity
		end
		self.effective_visible = parent.effective_visible and self.visible
		self.effective_enabled = parent.effective_enabled and self.enabled
	else
		self.effective_opacity = self.opacity
		self.render_opacity = self.opacity
		self.effective_visible = self.visible
		self.effective_enabled = self.enabled
	end
	self.present = (not parent or parent.present)
		and self.effective_opacity > 0.001 and self.scale_x ~= 0 and self.scale_y ~= 0
	local input_present = self.effective_visible and self.effective_enabled
		and self.present and self.cull_mask == 0
	local parent_input_present = not parent or (parent.effective_visible
		and parent.effective_enabled and parent.present and parent.cull_mask == 0)
	if was_input_present and not input_present and parent_input_present
		and self.screen and self.screen.inputs
	then
		self.screen.inputs:clearSubtree(self)
	end
end

---@private
---@param root_scale number
function View:composeGeometry(root_scale)
	local sx = self.scale_x * self.layout_sx * root_scale
	local sy = self.scale_y * self.layout_sy * root_scale
	local w = self.width
	local h = self.height
	local px = self.pivot[1] * w
	local py = self.pivot[2] * h
	self.transform:setTransformation(
		(self.x + self.offset_x + self.layout_dx + px) * root_scale,
		(self.y + self.offset_y + self.layout_dy + py) * root_scale,
		self.rotation,
		sx, sy,
		px, py
	)
	local world_transform = self.world_transform
	world_transform:reset()
	if self.parent then
		world_transform:apply(self.parent.world_transform)
	end
	world_transform:apply(self.transform)
	composeClipRect(self)
	local clip_rect = self.clip_rect
	if clip_rect and (clip_rect[3] <= 0 or clip_rect[4] <= 0) then
		self.cull_mask = bit.bor(self.cull_mask, self.CULL_CLIP_EMPTY)
	else
		self.cull_mask = bit.band(self.cull_mask, bit.bnot(self.CULL_CLIP_EMPTY))
	end
end

---Returns the screen-space axis-aligned bounds of the transformed view.
---@return number x
---@return number y
---@return number width
---@return number height
function View:getWorldBounds()
	local transform = self.world_transform
	local x1, y1 = transform:transformPoint(0, 0)
	local x2, y2 = transform:transformPoint(self.width, 0)
	local x3, y3 = transform:transformPoint(0, self.height)
	local x4, y4 = transform:transformPoint(self.width, self.height)
	local left = math.min(x1, x2, x3, x4)
	local top = math.min(y1, y2, y3, y4)
	local right = math.max(x1, x2, x3, x4)
	local bottom = math.max(y1, y2, y3, y4)
	return left, top, right - left, bottom - top
end

local function composeRecursive(view, root_scale, opacity_only)
	view:compose(root_scale, opacity_only)
	for i = 1, #view.children do
		composeRecursive(view.children[i], 1, opacity_only)
	end
end

---Recompose this view and its descendants without running layout.
---@param opacity_only boolean? Only opacity, visibility or enabled changed; matrices and clip rects are kept
function View:composeSubtree(opacity_only)
	local screen = self.screen
	local first = self.flat_index
	local last = self.flat_subtree_end
	if screen and not screen.dirty and first and last then
		for i = first, last do
			local view = screen.views[i]
			view:compose(view.parent and 1 or screen.ui_scale, opacity_only)
		end
		return
	end

	composeRecursive(self, self.parent and 1 or (screen and screen.ui_scale or 1), opacity_only)
end

---@param target string
---@param to number
---@param duration number
---@param easing gui.anim.EasingName|gui.anim.Easing?
---@param on_complete (fun(view: gui.View))?
---@return gui.View
function View:transformTo(target, to, duration, easing, on_complete)
	Animation.transformTo(self, target, to, duration, easing, on_complete)
	return self
end

---Advance this view's animations. Called by the Screen, which afterwards recomposes
---the affected subtrees once and runs the collected completions.
---@param dt number
---@param completions any[]? Flat {view, callback, ...} list, created on first use
---@return integer kind What changed: gui.view.Animation.NONE|OPACITY|GEOMETRY
---@return any[]? completions
function View:stepAnimations(dt, completions)
	assert(type(dt) == "number" and dt >= 0, "animation dt must be non-negative")
	local kind
	kind, completions = Animation.step(self, dt, completions)
	local tween = self.layout_tween
	if tween then
		local progress = math.min(1, (self.animation_time - tween.start) / tween.duration)
		local left = progress < 1 and 1 - tween.easing(progress) or 0
		self.layout_dx, self.layout_dy = tween.dx * left, tween.dy * left
		self.layout_sx, self.layout_sy = 1 + (tween.sx - 1) * left, 1 + (tween.sy - 1) * left
		if progress >= 1 then
			self.layout_tween = nil
		end
		kind = Animation.GEOMETRY
	end
	return kind, completions
end

---True while a transform is running or waiting for its delay.
---@return boolean
function View:hasTransforms()
	return Animation.has(self)
end

---True while a transform or a layout transition glide is running.
---@return boolean
function View:isAnimating()
	return Animation.has(self) or self.layout_tween ~= nil
end

---Jump transforms to their end values and run their completions.
---@param target string?
---@return gui.View
function View:finishTransforms(target)
	Animation.finish(self, target)
	return self
end

---Drop transforms without applying or completing them.
---@param target string?
---@return gui.View
function View:clearTransforms(target)
	Animation.clear(self, target)
	return self
end

---Animations chained on the result start `duration` after everything scheduled so far has
---ended: `view:fadeIn(0.2):delay(1):fadeOut(0.2)`. Later calls on the view are not delayed.
---@param duration number
---@return gui.view.Animation.Delayed
function View:delay(duration)
	return Animation.Delayed(self, duration)
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
	self:transformTo("offset_x", x, duration, easing)
	return self:transformTo("offset_y", y, duration, easing)
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
	self:transformTo("scale_x", scale_x, duration, easing)
	return self:transformTo("scale_y", scale_y, duration, easing)
end

---@param pivot_x number
---@param pivot_y number
---@param duration number
---@param easing gui.anim.EasingName|gui.anim.Easing?
---@return gui.View
function View:pivotTo(pivot_x, pivot_y, duration, easing)
	self:transformTo("pivot_x", pivot_x, duration, easing)
	return self:transformTo("pivot_y", pivot_y, duration, easing)
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

---Queue removal once an expired view has no transforms left.
function View:checkExpired()
	if self.expired and not self:hasTransforms() and self.screen then
		self.screen:queueExpire(self)
	end
end

---@param x number
---@param y number
---@return gui.View
function View:setOffset(x, y)
	if self.offset_x == x and self.offset_y == y then return self end
	self.offset_x = x
	self.offset_y = y
	self:composeSubtree()
	return self
end

---@param rotation number
---@return gui.View
function View:setRotation(rotation)
	if self.rotation == rotation then return self end
	self.rotation = rotation
	self:composeSubtree()
	return self
end

---@param scale_x number
---@param scale_y number
---@return gui.View
function View:setScale(scale_x, scale_y)
	if self.scale_x == scale_x and self.scale_y == scale_y then return self end
	self.scale_x = scale_x
	self.scale_y = scale_y
	self:composeSubtree()
	return self
end

---@param pivot_x number
---@param pivot_y number
---@return gui.View
function View:setPivot(pivot_x, pivot_y)
	if self.pivot[1] == pivot_x and self.pivot[2] == pivot_y then return self end
	self.pivot = {pivot_x, pivot_y}
	self:composeSubtree()
	return self
end

---@param opacity number
---@return gui.View
function View:setOpacity(opacity)
	assert(opacity >= 0 and opacity <= 1, "opacity must be between 0 and 1")
	if self.opacity == opacity then return self end
	self.opacity = opacity
	self:composeSubtree(true)
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

---Tests whether a window-space point is over this view and not clipped away by an ancestor.
---@param screen_x number
---@param screen_y number
---@return boolean
function View:isPointerOver(screen_x, screen_y)
	if not self:isMouseOver(screen_x, screen_y) then
		return false
	end
	local clip_rect = self.clip_rect
	return not clip_rect or (clip_rect[3] > 0 and clip_rect[4] > 0
		and screen_x >= clip_rect[1] and screen_x <= clip_rect[1] + clip_rect[3]
		and screen_y >= clip_rect[2] and screen_y <= clip_rect[2] + clip_rect[4])
end

---@param inputs gui.Inputs
function View:acceptInputs(inputs)
	for i = #self.children, 1, -1 do
		self.children[i]:acceptInputs(inputs)
	end
	inputs:processView(self)
end

---Override. Handles semantic input actions. Front-most views run first and
---may consume action edges before lower-priority views observe them.
---@param inputs gui.Inputs
function View:onHandleInputs(inputs) end

---Override. Draws in local space: [0, width] x [0, height].
function View:draw() end

---Override. Called every frame with the frame delta.
---@param dt number
function View:update(dt) end

return View
