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
	local screen = assert(self.screen, "CompositeView must be attached before layout")
	local scale = screen.ui_scale
	local width = math.ceil(self.width * scale)
	local height = math.ceil(self.height * scale)
	if width <= 0 or height <= 0 then
		if self.canvas then
			self.canvas:release()
			self.canvas = nil
		end
		self.canvas_scale = scale
		return
	end

	if self.canvas then
		local old_canvas_width, old_canvas_height = self.canvas:getDimensions()
		if old_canvas_width == width and old_canvas_height == height then
			self.canvas_scale = scale
			return
		end
		self.canvas:release()
	end
	self.canvas = love.graphics.newCanvas(width, height)
	self.canvas_scale = scale
end

function CompositeView:unload()
	if self.canvas then
		self.canvas:release()
		self.canvas = nil
	end
end

return CompositeView
