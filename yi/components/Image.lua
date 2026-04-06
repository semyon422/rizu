local View = require("ui.View")

---@alias yi.ImageMode
---| "none"
---| "stretch"
---| "fit"

---@class yi.ImageParams
---@field atlas love.Image
---@field quad love.Quad
---@field color ui.Color?
---@field mode yi.ImageMode?

---@class yi.Image : ui.View
---@operator call: yi.Image
local Image = View + {}

local temp_tf = love.math.newTransform()

---@param params yi.ImageParams
function Image:new(params)
	View.new(self)
	self.atlas = assert(params.atlas, "Image atlas is required")
	self.quad = assert(params.quad, "Image quad is required")
	self.color = params.color or {1, 1, 1, 1}
	self.mode = params.mode or "none"
	self.layout_scale_x = 1
	self.layout_scale_y = 1

	local _, _, w, h = self.quad:getViewport()
	self.width = w
	self.height = h
end

function Image:onLayoutUpdate()
	if self.mode == "none" or not self.box then
		self.layout_scale_x = 1
		self.layout_scale_y = 1
		return
	end

	local box_w, box_h = self.box:getDimensions()
	local next_scale_x = 1
	local next_scale_y = 1

	if self.mode == "stretch" then
		next_scale_x = box_w / self.width
		next_scale_y = box_h / self.height
	elseif self.mode == "fit" then
		local scale = math.min(box_w / self.width, box_h / self.height)
		next_scale_x = scale
		next_scale_y = scale
	end

	self.layout_scale_x = next_scale_x
	self.layout_scale_y = next_scale_y
end

function Image:updateTransform()
	local box = self.box
	assert(box, "yi.Image:updateTransform() requires self.box")

	local pivot = self.pivot
	local box_width = box.width
	local box_height = box.height
	local ax, ay = box_width * pivot[1], box_height * pivot[2]
	local ox, oy = self.width * pivot[1], self.height * pivot[2]
	local x, y = self.x + ax, self.y + ay
	local sx = self.scale_x * self.layout_scale_x
	local sy = self.scale_y * self.layout_scale_y
	local r = self.rotation

	temp_tf:setTransformation(x, y, r, sx, sy, ox, oy)
	self.transform:reset()
	self.transform:apply(box.transform)
	self.transform:apply(temp_tf)
end

function Image:draw()
	love.graphics.setColor(self.color)
	love.graphics.draw(self.atlas, self.quad)
end

return Image
