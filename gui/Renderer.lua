local class = require("class")
local Painter = require("gui.Painter")

local DRAW_ITEM = 1
local BEGIN_COMPOSITE = 2
local END_COMPOSITE = 3

---@alias gui.RenderCommand 1|2|3

---@class gui.Renderer
---@operator call: gui.Renderer
---@field commands (gui.RenderCommand|gui.View)[] Packed command stream
---@field command_count integer
local Renderer = class()

function Renderer:new()
	---@type (gui.RenderCommand|gui.View)[]
	self.commands = {}
	self.command_count = 0
	---@type love.Transform
	self.relative_transform = love.math.newTransform()
	---@type love.Transform
	self.inverse_transform = love.math.newTransform()
	---@type gui.CompositeView[]
	self.composite_stack = {}
end

---Start rebuilding the packed command stream.
function Renderer:beginBuild()
	self.commands = {}
	self.command_count = 0
end

---@param self gui.Renderer
---@param command gui.RenderCommand
---@param view gui.View?
local function addCommand(self, command, view)
	local index = self.command_count + 1
	self.commands[index] = command
	if view then
		self.commands[index + 1] = view
		self.command_count = index + 1
	else
		self.command_count = index
	end
end

---@param view gui.View
function Renderer:addView(view)
	addCommand(self, DRAW_ITEM, view)
end

---@param view gui.CompositeView
function Renderer:beginComposite(view)
	addCommand(self, BEGIN_COMPOSITE, view)
end

function Renderer:endComposite()
	addCommand(self, END_COMPOSITE)
end

function Renderer:clear()
	self.commands = {}
	self.command_count = 0
end

---@param self gui.Renderer
---@param transform love.Transform
---@param boundary gui.CompositeView
---@param scale number
local function replaceRelativeTransform(self, transform, boundary, scale)
	local relative = self.relative_transform
	relative:reset()
	relative:scale(scale, scale)
	if boundary then
		local x0, y0 = boundary.world_transform:inverseTransformPoint(0, 0)
		local xx, yx = boundary.world_transform:inverseTransformPoint(1, 0)
		local xy, yy = boundary.world_transform:inverseTransformPoint(0, 1)
		local inverse = self.inverse_transform
		inverse:setMatrix(
			xx - x0, xy - x0, 0, x0,
			yx - y0, yy - y0, 0, y0,
			0, 0, 1, 0,
			0, 0, 0, 1
		)
		relative:apply(inverse)
	end
	relative:apply(transform)
	love.graphics.replaceTransform(relative)
end

---@param rect {[1]: number, [2]: number, [3]: number, [4]: number}?
---@param boundary gui.CompositeView?
---@param scale number
local function setScissor(rect, boundary, scale)
	if not rect then
		love.graphics.setScissor()
		return
	end
	local x1, y1 = rect[1], rect[2]
	local x2, y2 = x1 + rect[3], y1 + rect[4]
	if boundary then
		x1, y1 = boundary.world_transform:inverseTransformPoint(x1, y1)
		x2, y2 = boundary.world_transform:inverseTransformPoint(x2, y2)
	end
	x1, x2 = math.min(x1, x2) * scale, math.max(x1, x2) * scale
	y1, y2 = math.min(y1, y2) * scale, math.max(y1, y2) * scale
	love.graphics.setScissor(x1, y1, x2 - x1, y2 - y1)
end

---Execute the cached command stream.
function Renderer:draw()
	local commands = self.commands
	local command_count = self.command_count
	local composite_stack = self.composite_stack
	assert(#composite_stack == 0, "composite stack was not cleared")
	local initial_canvas = love.graphics.getCanvas()
	local index = 1
	while index <= command_count do
		local command = commands[index]
		if command == DRAW_ITEM then
			local view = commands[index + 1]
			---@cast view gui.View
			if not view.detached and view.cull_mask == 0 and view.effective_visible and view.present then
				local boundary = composite_stack[#composite_stack]
				local scale = 1
				if boundary then
					scale = boundary.canvas_scale
					replaceRelativeTransform(self, view.world_transform, boundary, scale)
				else
					love.graphics.replaceTransform(view.world_transform)
				end
				setScissor(view.clip_rect, boundary, scale)
				love.graphics.setBlendMode("alpha")
				Painter.begin(view.render_opacity)
				view:draw()
			end
			index = index + 2
		elseif command == BEGIN_COMPOSITE then
			local composite = commands[index + 1]
			---@cast composite gui.CompositeView
			if composite.detached or composite.cull_mask ~= 0
				or not composite.effective_visible or not composite.present
			then
				local depth = 1
				index = index + 2
				while depth > 0 do
					local nested_command = commands[index]
					if nested_command == BEGIN_COMPOSITE then
						depth = depth + 1
						index = index + 2
					elseif nested_command == END_COMPOSITE then
						depth = depth - 1
						index = index + 1
					elseif nested_command == DRAW_ITEM then
						index = index + 2
					else
						error(("unknown render command: %s"):format(tostring(nested_command)))
					end
				end
			else
				composite_stack[#composite_stack + 1] = composite
				love.graphics.setCanvas(composite.canvas)
				love.graphics.origin()
				love.graphics.setScissor()
				love.graphics.clear(0, 0, 0, 0)
				love.graphics.setBlendMode("alpha")
				index = index + 2
			end
		elseif command == END_COMPOSITE then
			local composite = assert(composite_stack[#composite_stack], "unbalanced composite commands")
			composite_stack[#composite_stack] = nil
			local parent = composite_stack[#composite_stack]
			love.graphics.setCanvas(parent and parent.canvas or initial_canvas)
			if composite.canvas and not composite.detached and composite.cull_mask == 0
				and composite.effective_visible and composite.present
			then
				local scale = parent and parent.canvas_scale or 1
				replaceRelativeTransform(self, composite.world_transform, parent, scale)
				setScissor(composite.clip_rect, parent, scale)
				local opacity = composite.render_opacity
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
	assert(#composite_stack == 0, "unbalanced composite commands")
	love.graphics.setCanvas(initial_canvas)
	love.graphics.setBlendMode("alpha")
	love.graphics.setScissor()
	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.origin()
end

return Renderer
