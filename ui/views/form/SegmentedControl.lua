local FormControl = require("ui.views.form.FormControl")
local Colors = require("ui.Colors")
local Painter = require("gui.Painter")
local Resources = require("ui.Resources")

---@class ui.views.form.SegmentedControlParams
---@field label string
---@field options any[]
---@field value any
---@field format? fun(value: any): string
---@field on_change? fun(value: any)

---A compact choice control which displays every option in one row.
---@class ui.views.form.SegmentedControl : ui.views.form.FormControl
---@operator call: ui.views.form.SegmentedControl
---@field options any[]
---@field value any
---@field label_text string
---@field format fun(value: any): string
---@field on_change fun(value: any)?
---@field font love.Font
---@field cell_widths number[]
---@field background_left gui.Sprite
---@field background_middle gui.Sprite
---@field background_right gui.Sprite
local SegmentedControl = FormControl + {}

local HEIGHT = 65
local BODY_Y = 25
local BODY_HEIGHT = 40
local HORIZONTAL_PADDING = 16

---@param value any
---@return string
local function defaultFormat(value)
	return tostring(value)
end

---@param params ui.views.form.SegmentedControlParams
function SegmentedControl:new(params)
	FormControl.new(self)
	self.options = params.options
	self.value = params.value
	self.label_text = params.label
	self.format = params.format or defaultFormat
	self.on_change = params.on_change
	self.font = Resources.getFont("medium", 16)
	self.background_left = Resources.sprites.segmented_bg_left
	self.background_middle = Resources.sprites.segmented_bg_middle
	self.background_right = Resources.sprites.segmented_bg_right
	self.cell_widths = {}

	local width = 0
	for index, option in ipairs(self.options) do
		local cell_width = self.font:getWidth(self.format(option)) + HORIZONTAL_PADDING * 2
		self.cell_widths[index] = cell_width
		width = width + cell_width
	end
	self:setSize(width, HEIGHT)
	self.handles_mouse_input = true
end

---@return boolean selectable
function SegmentedControl:canBeSelected()
	return FormControl.canBeSelected(self) and #self.options > 0
end

---@param value any
---@param notify boolean?
function SegmentedControl:setValue(value, notify)
	if self.value == value then
		return
	end
	self.value = value
	if notify and self.on_change then
		self.on_change(value)
	end
end

---@return integer? index
function SegmentedControl:getSelectedIndex()
	for index, option in ipairs(self.options) do
		if option == self.value then
			return index
		end
	end
end

---@param index integer
---@return boolean changed
function SegmentedControl:selectIndex(index)
	local option_count = #self.options
	if option_count == 0 then
		return false
	end
	index = ((index - 1) % option_count) + 1
	local previous = self.value
	self:setValue(self.options[index], true)
	return self.value ~= previous
end

---@param e gui.KeyDownEvent?
---@return boolean activated
function SegmentedControl:activate(e)
	if #self.options == 0 then
		return false
	end
	self:selectIndex((self:getSelectedIndex() or 0) + 1)
	return true
end

---@param e gui.KeyDownEvent
---@return boolean handled
function SegmentedControl:onFormKeyDown(e)
	local direction = e.key == "left" and -1 or e.key == "right" and 1 or nil
	if not direction or #self.options == 0 then
		return false
	end
	local selected_index = self:getSelectedIndex()
	if not selected_index then
		selected_index = direction > 0 and 0 or 1
	end
	self:selectIndex(selected_index + direction)
	return true
end

---@param screen_x number
---@param screen_y number
---@return integer? index
function SegmentedControl:getIndexAt(screen_x, screen_y)
	local local_x = self.world_transform:inverseTransformPoint(screen_x, screen_y)
	if local_x < 0 or local_x > self.width then
		return
	end
	local right = 0
	for index, width in ipairs(self.cell_widths) do
		right = right + width
		if local_x <= right then
			return index
		end
	end
end

---@param e gui.MouseClickEvent
---@return boolean? handled
function SegmentedControl:onMouseClick(e)
	if e.button ~= 1 then
		return
	end
	local index = self:getIndexAt(e.x, e.y)
	if index then
		self:selectIndex(index)
		return true
	end
end

---@param self ui.views.form.SegmentedControl
---@param x number
---@param width number
local function drawBackground(self, x, width)
	local left_width = self.background_left:getWidth()
	local right_width = self.background_right:getWidth()
	local middle_width = width - left_width - right_width
	self.background_left:draw(x, BODY_Y)
	if middle_width > 0 then
		self.background_middle:draw(
			x + left_width,
			BODY_Y,
			0,
			middle_width / self.background_middle:getWidth(),
			1
		)
	end
	self.background_right:draw(x + width - right_width, BODY_Y)
end

function SegmentedControl:draw()
	Painter.setColorTable(Colors.elements)
	drawBackground(self, 0, self.width)

	local selected_index = self:getSelectedIndex()
	local x = 0
	if selected_index then
		for index = 1, selected_index - 1 do
			x = x + self.cell_widths[index]
		end
		Painter.setColorTable(Colors.accent)
		drawBackground(self, x, self.cell_widths[selected_index])
	end

	Painter.setColorTable(Colors.text)
	Painter.snapToPixel()
	love.graphics.setFont(self.font)
	love.graphics.print(self.label_text, 0, 0)
	x = 0
	local text_y = BODY_Y + (BODY_HEIGHT - self.font:getHeight()) / 2
	for index, option in ipairs(self.options) do
		local width = self.cell_widths[index]
		Painter.setColorTable(index == selected_index and Colors.text_inverted or Colors.text)
		love.graphics.printf(self.format(option), x, text_y, width, "center")
		x = x + width
	end
end

return SegmentedControl
