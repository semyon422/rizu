local View = require("gui.View")

---@class gui.CompositeView : gui.View
---@operator call: gui.CompositeView
---@field canvas love.Canvas?
---@field canvas_scale number
local CompositeView = View + {}

function CompositeView:new()
	View.new(self)
	self.is_composite = true
	self.canvas = nil
	self.canvas_scale = 1
end

---@param old_x number
---@param old_y number
---@param old_width number
---@param old_height number
function CompositeView:onLayoutChanged(old_x, old_y, old_width, old_height)
	self:prepareCanvas()
end

---Returns the content canvas for the current rect and ui_scale, replacing a stale one.
---The Renderer calls this before every use, so a ui_scale change that leaves the rect alone is still followed.
---@return love.Canvas? canvas nil when the view has no pixels
function CompositeView:prepareCanvas()
	local screen = assert(self.screen, "CompositeView must be attached before layout")
	local scale = screen.ui_scale
	local width = math.ceil(self.width * scale)
	local height = math.ceil(self.height * scale)
	self.canvas_scale = scale
	if width <= 0 or height <= 0 then
		self:releaseCanvas()
		return nil
	end

	local canvas = self.canvas
	if canvas and canvas:getWidth() == width and canvas:getHeight() == height then
		return canvas
	end
	self:releaseCanvas()
	self.canvas = love.graphics.newCanvas(width, height)
	return self.canvas
end

function CompositeView:releaseCanvas()
	if self.canvas then
		self.canvas:release()
		self.canvas = nil
	end
end

---Hook for subclasses that render extra output from their finished content canvas.
---Called by the Renderer before the view's transform for the parent canvas is set.
---@param restore_canvas love.Canvas? Canvas that must be current again afterwards.
function CompositeView:postProcess(restore_canvas)
end

---Hook for subclasses that draw something under their content, in local logical space.
---@param opacity number
function CompositeView:drawUnderlay(opacity)
end

function CompositeView:unload()
	self:releaseCanvas()
end

return CompositeView
