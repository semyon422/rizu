local View = require("gui.View")

---Blends its subtree as one layer. The canvas exists only while it is needed: the view is
---visible and either translucent or post-processed. Otherwise its children draw straight into
---the parent target, where they are not cut off at this view's rect; set `clip` if they overflow.
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

---A hidden composite gives its canvas back; the Renderer asks for a new one when it is drawn again.
---@protected
---@param root_scale number
---@param opacity_only boolean?
function CompositeView:compose(root_scale, opacity_only)
	View.compose(self, root_scale, opacity_only)
	if not self.effective_visible then
		self:releaseCanvas()
	end
end

---Returns the content canvas for the current rect and ui_scale, creating or replacing it as needed.
---The Renderer calls this each time it is about to draw the view through its canvas.
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
