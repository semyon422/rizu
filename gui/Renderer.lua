local class = require("class")
local CompositeView = require("gui.CompositeView")
local Painter = require("gui.Painter")

local DRAW_ITEM = 1
local BEGIN_COMPOSITE = 2
local END_COMPOSITE = 3

---@alias gui.RenderCommand 1|2|3

---Draws a screen from a packed command stream:
---  DRAW_ITEM, view, next         draw one view
---  BEGIN_COMPOSITE, view, next   open a composite boundary
---  END_COMPOSITE                 close it
---`next` is the command index after the view's whole subtree. Visibility and presence are
---inherited, so a hidden view skips its subtree by jumping there.
---@class gui.Renderer
---@operator call: gui.Renderer
---@field commands (gui.RenderCommand|gui.View|integer)[] Packed command stream
---@field command_count integer
---@field relative_transform love.Transform
---@field private composite_stack gui.CompositeView[] Open composites while drawing
---@field private boundary_stack (gui.CompositeView|false)[] Boundary in effect inside each open composite
---@field private inverse_stack (love.Transform|false)[] That boundary's inverse world transform
---@field private inverse_pool love.Transform[] One reusable inverse per nesting depth
local Renderer = class()

function Renderer:new()
	---@type (gui.RenderCommand|gui.View|integer)[]
	self.commands = {}
	self.command_count = 0
	self.relative_transform = love.math.newTransform()
	self.composite_stack = {}
	self.boundary_stack = {}
	self.inverse_stack = {}
	self.inverse_pool = {}
end

---Start rebuilding the packed command stream.
function Renderer:beginBuild()
	self.commands = {}
	self.command_count = 0
end

---@param self gui.Renderer
---@param command gui.RenderCommand
---@param view gui.View
---@return integer slot Pass to endSubtree once the view's descendants are added
local function addCommand(self, command, view)
	local index = self.command_count + 1
	self.commands[index] = command
	self.commands[index + 1] = view
	self.commands[index + 2] = index + 3
	self.command_count = index + 2
	return index
end

---@param view gui.View
---@return integer slot
function Renderer:addView(view)
	return addCommand(self, DRAW_ITEM, view)
end

---@param view gui.CompositeView
---@return integer slot
function Renderer:beginComposite(view)
	return addCommand(self, BEGIN_COMPOSITE, view)
end

function Renderer:endComposite()
	local index = self.command_count + 1
	self.commands[index] = END_COMPOSITE
	self.command_count = index
end

---Record where the commands of a view's subtree end.
---@param slot integer
function Renderer:endSubtree(slot)
	self.commands[slot + 2] = self.command_count + 1
end

function Renderer:clear()
	self.commands = {}
	self.command_count = 0
end

---Fill `inverse` with the inverse of a boundary's world transform without allocating.
---@param inverse love.Transform
---@param world_transform love.Transform
local function setInverse(inverse, world_transform)
	local x0, y0 = world_transform:inverseTransformPoint(0, 0)
	local xx, yx = world_transform:inverseTransformPoint(1, 0)
	local xy, yy = world_transform:inverseTransformPoint(0, 1)
	inverse:setMatrix(
		xx - x0, xy - x0, 0, x0,
		yx - y0, yy - y0, 0, y0,
		0, 0, 1, 0,
		0, 0, 0, 1
	)
end

---@param self gui.Renderer
---@param transform love.Transform
---@param inverse love.Transform Inverse world transform of the boundary being drawn into
---@param scale number
local function replaceRelativeTransform(self, transform, inverse, scale)
	local relative = self.relative_transform
	relative:reset()
	relative:scale(scale, scale)
	relative:apply(inverse)
	relative:apply(transform)
	love.graphics.replaceTransform(relative)
end

---@param rect {[1]: number, [2]: number, [3]: number, [4]: number}?
---@param inverse love.Transform? Inverse world transform of the boundary being drawn into
---@param scale number
local function setScissor(rect, inverse, scale)
	if not rect then
		love.graphics.setScissor()
		return
	end
	local x1, y1 = rect[1], rect[2]
	local x2, y2 = x1 + rect[3], y1 + rect[4]
	if inverse then
		x1, y1 = inverse:transformPoint(x1, y1)
		x2, y2 = inverse:transformPoint(x2, y2)
	end
	x1, x2 = math.min(x1, x2) * scale, math.max(x1, x2) * scale
	y1, y2 = math.min(y1, y2) * scale, math.max(y1, y2) * scale
	love.graphics.setScissor(x1, y1, x2 - x1, y2 - y1)
end

---A composite needs its canvas only to blend its content as one layer or to post-process it.
---@param composite gui.CompositeView
---@return boolean
local function needsCanvas(composite)
	return composite.render_opacity ~= 1
		or composite.postProcess ~= CompositeView.postProcess
		or composite.drawUnderlay ~= CompositeView.drawUnderlay
end

---Execute the cached command stream.
function Renderer:draw()
	local commands = self.commands
	local command_count = self.command_count
	-- Per open composite: the composite, and the boundary its children draw into.
	-- A composite drawn without a canvas passes its parent's boundary down.
	local composite_stack = self.composite_stack
	local boundary_stack = self.boundary_stack
	local inverse_stack = self.inverse_stack
	local inverse_pool = self.inverse_pool
	local depth = 0
	local boundary ---@type gui.CompositeView?
	local inverse ---@type love.Transform?
	local initial_canvas = love.graphics.getCanvas()
	local index = 1
	while index <= command_count do
		local command = commands[index]
		if command == DRAW_ITEM then
			local view = commands[index + 1]
			---@cast view gui.View
			if view.detached or not view.effective_visible or not view.present then
				index = commands[index + 2] --[[@as integer]]
			elseif view.cull_mask ~= 0 then
				-- Culling is per view: descendants may still be inside the viewport.
				index = index + 3
			else
				local scale = 1
				if boundary and inverse then
					scale = boundary.canvas_scale
					replaceRelativeTransform(self, view.world_transform, inverse, scale)
				else
					love.graphics.replaceTransform(view.world_transform)
				end
				setScissor(view.clip_rect, inverse, scale)
				love.graphics.setBlendMode("alpha")
				-- A composite drawing into its own canvas is opaque there; its opacity applies to the canvas.
				Painter.begin(view == boundary and 1 or view.render_opacity)
				view:draw()
				index = index + 3
			end
		elseif command == BEGIN_COMPOSITE then
			local composite = commands[index + 1]
			---@cast composite gui.CompositeView
			local direct = not needsCanvas(composite)
			if direct then
				composite:releaseCanvas()
			end
			-- A composite without a canvas has nothing to draw into; its subtree must not leak to the parent target.
			if composite.detached or composite.cull_mask ~= 0
				or not composite.effective_visible or not composite.present
				or not (direct or composite:prepareCanvas())
			then
				index = commands[index + 2] --[[@as integer]]
			else
				depth = depth + 1
				composite_stack[depth] = composite
				if not direct then
					boundary = composite
					inverse = inverse_pool[depth]
					if not inverse then
						inverse = love.math.newTransform()
						inverse_pool[depth] = inverse
					end
					setInverse(inverse, composite.world_transform)
					love.graphics.setCanvas(composite.canvas)
					love.graphics.origin()
					love.graphics.setScissor()
					love.graphics.clear(0, 0, 0, 0)
					love.graphics.setBlendMode("alpha")
				end
				boundary_stack[depth] = boundary or false
				inverse_stack[depth] = inverse or false
				index = index + 3
			end
		elseif command == END_COMPOSITE then
			local composite = assert(composite_stack[depth], "unbalanced composite commands")
			local had_canvas = boundary == composite
			composite_stack[depth] = nil
			depth = depth - 1
			boundary = boundary_stack[depth] or nil
			inverse = inverse_stack[depth] or nil
			if had_canvas then
				local target = boundary and boundary.canvas or initial_canvas
				love.graphics.setCanvas(target)
				local scale = boundary and boundary.canvas_scale or 1
				-- Post-processing (e.g. a shadow blur) reads the finished content; it switches canvases,
				-- so it has to run before the transform and scissor for the parent are set.
				composite:postProcess(target)
				if boundary and inverse then
					replaceRelativeTransform(self, composite.world_transform, inverse, scale)
				else
					love.graphics.replaceTransform(composite.world_transform)
				end
				setScissor(composite.clip_rect, inverse, scale)
				local opacity = composite.render_opacity
				composite:drawUnderlay(opacity)
				love.graphics.setColor(opacity, opacity, opacity, opacity)
				love.graphics.setBlendMode("alpha", "premultiplied")
				love.graphics.draw(composite.canvas, 0, 0, 0,
					1 / composite.canvas_scale, 1 / composite.canvas_scale)
			end
			index = index + 1
		else
			error(("unknown render command: %s"):format(tostring(command)))
		end
	end
	assert(depth == 0, "unbalanced composite commands")
	love.graphics.setCanvas(initial_canvas)
	love.graphics.setBlendMode("alpha")
	love.graphics.setScissor()
	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.origin()
end

return Renderer
