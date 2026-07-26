local class = require("class")

---@alias gui.NineSliceQuads [love.Quad, love.Quad, love.Quad, love.Quad, love.Quad, love.Quad, love.Quad, love.Quad, love.Quad]

---@class gui.NineSliceUsage
---@operator call: gui.NineSliceUsage
---@field texture love.Texture
---@field quads gui.NineSliceQuads
---@field width number
---@field height number
---@field private batch love.SpriteBatch
---@field private left_width number
---@field private center_width number
---@field private right_width number
---@field private top_height number
---@field private center_height number
---@field private bottom_height number
local NineSliceUsage = class()

---@param quad love.Quad
---@return number width
---@return number height
local function getQuadSize(quad)
	local _, _, width, height = quad:getViewport()
	return width, height
end

---@param actual number
---@param expected number
---@param message string
local function assertEqual(actual, expected, message)
	assert(actual == expected, message)
end

---@param texture love.Texture
---@param quads gui.NineSliceQuads Quads ordered left-to-right, top-to-bottom.
function NineSliceUsage:new(texture, quads)
	assert(texture, "nine-slice texture is required")
	assert(#quads == 9, "nine-slice requires exactly 9 quads")

	self.texture = texture
	self.quads = quads
	self.batch = love.graphics.newSpriteBatch(texture, 9, "static")

	local left_width, top_height = getQuadSize(quads[1])
	local center_width, top_center_height = getQuadSize(quads[2])
	local right_width, top_right_height = getQuadSize(quads[3])
	local middle_left_width, center_height = getQuadSize(quads[4])
	local middle_center_width, middle_center_height = getQuadSize(quads[5])
	local middle_right_width, middle_right_height = getQuadSize(quads[6])
	local bottom_left_width, bottom_height = getQuadSize(quads[7])
	local bottom_center_width, bottom_center_height = getQuadSize(quads[8])
	local bottom_right_width, bottom_right_height = getQuadSize(quads[9])

	assertEqual(top_center_height, top_height, "nine-slice top row heights must match")
	assertEqual(top_right_height, top_height, "nine-slice top row heights must match")
	assertEqual(middle_center_height, center_height, "nine-slice middle row heights must match")
	assertEqual(middle_right_height, center_height, "nine-slice middle row heights must match")
	assertEqual(bottom_center_height, bottom_height, "nine-slice bottom row heights must match")
	assertEqual(bottom_right_height, bottom_height, "nine-slice bottom row heights must match")
	assertEqual(middle_left_width, left_width, "nine-slice left column widths must match")
	assertEqual(bottom_left_width, left_width, "nine-slice left column widths must match")
	assertEqual(middle_center_width, center_width, "nine-slice center column widths must match")
	assertEqual(bottom_center_width, center_width, "nine-slice center column widths must match")
	assertEqual(middle_right_width, right_width, "nine-slice right column widths must match")
	assertEqual(bottom_right_width, right_width, "nine-slice right column widths must match")

	self.left_width = left_width
	self.center_width = center_width
	self.right_width = right_width
	self.top_height = top_height
	self.center_height = center_height
	self.bottom_height = bottom_height
	self:resize(left_width + center_width + right_width, top_height + center_height + bottom_height)
end

---@param width number
---@param height number
function NineSliceUsage:resize(width, height)
	width = math.max(width, self.left_width + self.right_width)
	height = math.max(height, self.top_height + self.bottom_height)

	self.width = width
	self.height = height

	local center_width = width - self.left_width - self.right_width
	local center_height = height - self.top_height - self.bottom_height
	local center_scale_x = center_width / self.center_width
	local center_scale_y = center_height / self.center_height
	local right_x = self.left_width + center_width
	local bottom_y = self.top_height + center_height

	self.batch:clear()
	self.batch:add(self.quads[1], 0, 0)
	self.batch:add(self.quads[2], self.left_width, 0, 0, center_scale_x, 1)
	self.batch:add(self.quads[3], right_x, 0)
	self.batch:add(self.quads[4], 0, self.top_height, 0, 1, center_scale_y)
	self.batch:add(self.quads[5], self.left_width, self.top_height, 0, center_scale_x, center_scale_y)
	self.batch:add(self.quads[6], right_x, self.top_height, 0, 1, center_scale_y)
	self.batch:add(self.quads[7], 0, bottom_y)
	self.batch:add(self.quads[8], self.left_width, bottom_y, 0, center_scale_x, 1)
	self.batch:add(self.quads[9], right_x, bottom_y)
	self.batch:flush()
end

---Draws at the origin. Supplying a size resizes the cached batch only when needed.
---@param width number
---@param height number
function NineSliceUsage:draw(width, height)
	width = math.max(width, self.left_width + self.right_width)
	height = math.max(height, self.top_height + self.bottom_height)
	if width ~= self.width or height ~= self.height then
		self:resize(width, height)
	end
	love.graphics.draw(self.batch)
end

return NineSliceUsage
