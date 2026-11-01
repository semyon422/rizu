local class = require("class")
local SpriteBatch = require("gui.SpriteBatch")

---@alias gui.NineSliceSprites [gui.AtlasImage, gui.AtlasImage, gui.AtlasImage, gui.AtlasImage, gui.AtlasImage, gui.AtlasImage, gui.AtlasImage, gui.AtlasImage, gui.AtlasImage]

---@class gui.NineSliceUsage
---@operator call: gui.NineSliceUsage
---@field sprites gui.NineSliceSprites
---@field width number
---@field height number
---@field open_top boolean
---@field open_bottom boolean
local NineSliceUsage = class()

---@param actual number
---@param expected number
---@param message string
local function assertEqual(actual, expected, message)
	assert(actual == expected, message)
end

---@param sprites gui.NineSliceSprites Sprites ordered left-to-right, top-to-bottom.
function NineSliceUsage:new(sprites)
	assert(#sprites == 9, "nine-slice requires exactly 9 sprites")
	self.sprites = sprites
	self.batch = SpriteBatch(sprites[1], 9, "static")

	local left_width, top_height = sprites[1]:getDimensions()
	local center_width, top_center_height = sprites[2]:getDimensions()
	local right_width, top_right_height = sprites[3]:getDimensions()
	local middle_left_width, center_height = sprites[4]:getDimensions()
	local middle_center_width, middle_center_height = sprites[5]:getDimensions()
	local middle_right_width, middle_right_height = sprites[6]:getDimensions()
	local bottom_left_width, bottom_height = sprites[7]:getDimensions()
	local bottom_center_width, bottom_center_height = sprites[8]:getDimensions()
	local bottom_right_width, bottom_right_height = sprites[9]:getDimensions()

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
	self.open_top = false
	self.open_bottom = false
	self:resize(left_width + center_width + right_width, top_height + center_height + bottom_height)
end

---@param width number
---@param height number
function NineSliceUsage:resize(width, height)
	width = math.max(width, self.left_width + self.right_width)
	height = math.max(height, self.top_height + self.bottom_height)
	self.width, self.height = width, height

	local center_width = width - self.left_width - self.right_width
	local center_height = height - self.top_height - self.bottom_height
	local center_scale_x = center_width / self.center_width
	local center_scale_y = center_height / self.center_height
	local right_x = self.left_width + center_width
	local bottom_y = self.top_height + center_height
	local sprites = self.sprites

	-- An open edge repeats the middle row, so stacked pieces share one rounded outline.
	local top = self.open_top and 3 or 0
	local bottom = self.open_bottom and 3 or 6
	local top_scale = self.open_top and self.top_height / self.center_height or 1
	local bottom_scale = self.open_bottom and self.bottom_height / self.center_height or 1

	self.batch:clear()
	self.batch:add(sprites[top + 1], 0, 0, 0, 1, top_scale)
	self.batch:add(sprites[top + 2], self.left_width, 0, 0, center_scale_x, top_scale)
	self.batch:add(sprites[top + 3], right_x, 0, 0, 1, top_scale)
	self.batch:add(sprites[4], 0, self.top_height, 0, 1, center_scale_y)
	self.batch:add(sprites[5], self.left_width, self.top_height, 0, center_scale_x, center_scale_y)
	self.batch:add(sprites[6], right_x, self.top_height, 0, 1, center_scale_y)
	self.batch:add(sprites[bottom + 1], 0, bottom_y, 0, 1, bottom_scale)
	self.batch:add(sprites[bottom + 2], self.left_width, bottom_y, 0, center_scale_x, bottom_scale)
	self.batch:add(sprites[bottom + 3], right_x, bottom_y, 0, 1, bottom_scale)
	self.batch:flush()
end

---Replaces the top or bottom row with the middle row: square corners and no stroke on that edge.
---@param top boolean
---@param bottom boolean
function NineSliceUsage:setOpenEdges(top, bottom)
	if top == self.open_top and bottom == self.open_bottom then return end
	self.open_top, self.open_bottom = top, bottom
	self:resize(self.width, self.height)
end

---@param width number
---@param height number
function NineSliceUsage:draw(width, height)
	width = math.max(width, self.left_width + self.right_width)
	height = math.max(height, self.top_height + self.bottom_height)
	if width ~= self.width or height ~= self.height then self:resize(width, height) end
	self.batch:draw()
end

---Draws texture pixels at 1:1 while filling dimensions expressed in logical units.
---@param width number
---@param height number
---@param ui_scale number
function NineSliceUsage:drawFixedScale(width, height, ui_scale)
	assert(type(ui_scale) == "number" and ui_scale > 0 and ui_scale < math.huge,
		"ui_scale must be a positive finite number")
	if ui_scale == 1 then
		self:draw(width, height)
		return
	end
	love.graphics.push("transform")
	love.graphics.scale(1 / ui_scale, 1 / ui_scale)
	self:draw(width * ui_scale, height * ui_scale)
	love.graphics.pop()
end

return NineSliceUsage
