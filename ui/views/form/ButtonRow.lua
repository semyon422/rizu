local FormControl = require("ui.views.form.FormControl")
local FormNavigation = require("ui.views.form.FormNavigation")
local Colors = require("ui.Colors")
local Painter = require("gui.Painter")
local Resources = require("ui.Resources")

---@class ui.views.form.ButtonRow.Button
---@field text string
---@field on_click fun()

---@class ui.views.form.ButtonRow.Params
---@field label string? Omit to leave out the label line.
---@field buttons ui.views.form.ButtonRow.Button[]

---A label over a row of small buttons. The arrows pick a button, Enter presses it.
---@class ui.views.form.ButtonRow : ui.views.form.FormControl
---@operator call: ui.views.form.ButtonRow
---@field label_text string?
---@field font love.Font
---@field body_y number
---@field background_left gui.Sprite
---@field background_middle gui.Sprite
---@field background_right gui.Sprite
---@field buttons ui.views.form.ButtonRow.Button[]
---@field button_widths number[]
---@field cursor integer
local ButtonRow = FormControl + {}

local BODY_Y = 25
local BODY_HEIGHT = 40
local GAP = 6
local HORIZONTAL_PADDING = 16

---@param params ui.views.form.ButtonRow.Params
function ButtonRow:new(params)
	FormControl.new(self)
	self.label_text = params.label
	self.buttons = params.buttons
	self.cursor = 1
	self.font = Resources.getFont("medium", 16)
	self.body_y = params.label and BODY_Y or 0
	self.background_left = Resources.sprites.segmented_bg_left
	self.background_middle = Resources.sprites.segmented_bg_middle
	self.background_right = Resources.sprites.segmented_bg_right

	self.button_widths = {}
	local width = -GAP ---@type number
	for i, button in ipairs(self.buttons) do
		self.button_widths[i] = self.font:getWidth(button.text) + HORIZONTAL_PADDING * 2
		width = width + self.button_widths[i] + GAP
	end
	if self.label_text then
		width = math.max(width, self.font:getWidth(self.label_text)) --[[@as number]]
	end
	self:setSize(width, self.body_y + BODY_HEIGHT)
	self.handles_mouse_input = true
end

---@param text string
function ButtonRow:setLabel(text)
	self.label_text = text
	self:setWidth(math.max(self.width, self.font:getWidth(text)))
end

---@param e gui.KeyDownEvent?
---@return boolean activated
function ButtonRow:activate(e)
	self.buttons[self.cursor].on_click()
	return true
end

---@param e gui.KeyDownEvent
---@return boolean handled
function ButtonRow:onFormKeyDown(e)
	local direction = e.key == "left" and -1 or e.key == "right" and 1 or nil
	if not direction then
		return false
	end
	self.cursor = math.max(1, math.min(self.cursor + direction, #self.buttons))
	return true
end

---@param screen_x number
---@param screen_y number
---@return integer? index
function ButtonRow:getIndexAt(screen_x, screen_y)
	local x, y = self.world_transform:inverseTransformPoint(screen_x, screen_y)
	if y < self.body_y or y > self.body_y + BODY_HEIGHT then
		return
	end
	local left = 0
	for index, width in ipairs(self.button_widths) do
		if x >= left and x <= left + width then
			return index
		end
		left = left + width + GAP
	end
end

---@param e gui.MouseClickEvent
---@return boolean? handled
function ButtonRow:onMouseClick(e)
	if e.button ~= 1 then
		return
	end
	local index = self:getIndexAt(e.x, e.y)
	if index then
		self.cursor = index
		self.buttons[index].on_click()
		return true
	end
end

---@return boolean
function ButtonRow:isKeyboardSelected()
	local form = self.parent and self.parent.parent
	---@cast form ui.views.form.Form?
	return form ~= nil and form.selected_control == self and form.navigation == FormNavigation.Keyboard
end

function ButtonRow:draw()
	local hovered ---@type integer?
	local inputs = self.screen and self.screen.inputs
	if self.mouse_over and inputs then
		hovered = self:getIndexAt(inputs.mouse_x, inputs.mouse_y)
	end
	local cursor = self:isKeyboardSelected() and self.cursor or nil

	local left_width = self.background_left:getWidth()
	local right_width = self.background_right:getWidth()
	local x = 0
	for index, width in ipairs(self.button_widths) do
		Painter.setColorTable((index == hovered or index == cursor) and Colors.surface_raised or Colors.surface)
		self.background_left:draw(x, self.body_y)
		self.background_middle:draw(x + left_width, self.body_y, 0,
			(width - left_width - right_width) / self.background_middle:getWidth(), 1)
		self.background_right:draw(x + width - right_width, self.body_y)
		x = x + width + GAP
	end

	Painter.snapToPixel()
	love.graphics.setFont(self.font)
	Painter.setColorTable(Colors.text)
	if self.label_text then
		love.graphics.print(self.label_text, 0, 0)
	end
	x = 0
	local text_y = self.body_y + (BODY_HEIGHT - self.font:getHeight()) / 2
	for index, button in ipairs(self.buttons) do
		love.graphics.printf(button.text, x, text_y, self.button_widths[index], "center")
		x = x + self.button_widths[index] + GAP
	end
end

return ButtonRow
