local View = require("gui.View")
local Painter = require("gui.Painter")
local Resources = require("ui.Resources")
local Sprite = require("gui.Sprite")
local Sounds = require("ui.Sounds")

---@class ui.screens.song_select.FooterButtonContent
---@field text string?
---@field icon gui.Sprite?
---@field reverse boolean? Draw the text before the icon.
---@field gap number? Gap between the icon and text.

---@class ui.screens.song_select.FooterButton : gui.View
---@operator call: ui.screens.song_select.FooterButton
---@field bg_color gui.Color
---@field content_color gui.Color
---@field text string?
---@field icon gui.Sprite?
---@field font love.Font
---@field on_click fun()?
---@field left gui.Sprite
---@field middle gui.Sprite
---@field right gui.Sprite
local FooterButton = View + {}

local SMALL_HEIGHT = 40
local LARGE_HEIGHT = 50
local HORIZONTAL_PADDING = 30
local DEFAULT_GAP = 10

---@param bg_color gui.Color
---@param large boolean
---@param content_color gui.Color
---@param content string|gui.Sprite|ui.screens.song_select.FooterButtonContent
---@param on_click fun()?
function FooterButton:new(bg_color, large, content_color, content, on_click)
	View.new(self)
	self.bg_color = bg_color
	self.content_color = content_color
	self.on_click = on_click
	self.font = Resources.getFont("regular", large and 24 or 16)

	if large then
		self.left = Resources.sprites.footer_button_large_left
		self.middle = Resources.sprites.footer_button_large_middle
		self.right = Resources.sprites.footer_button_large_right
	else
		self.left = Resources.sprites.footer_button_left
		self.middle = Resources.sprites.footer_button_middle
		self.right = Resources.sprites.footer_button_right
	end

	self.gap = DEFAULT_GAP
	self.reverse = false
	if type(content) == "string" then
		self.text = content
	elseif type(content) == "table" and Sprite * content then
		---@cast content gui.Sprite
		self.icon = content
	elseif type(content) == "table" then
		---@cast content ui.screens.song_select.FooterButtonContent
		assert(content.text or content.icon, "footer button content is empty")
		assert(not content.icon or Sprite * content.icon, "footer button icon is not a sprite")
		self.text = content.text
		self.icon = content.icon
		self.reverse = content.reverse or false
		self.gap = content.gap or DEFAULT_GAP
	else
		error("fifth parameter must be text, a sprite, or footer button content")
	end

	local content_width = self:getContentWidth()
	local minimum_width = self.left:getWidth() + self.right:getWidth()
	local width = math.max(minimum_width, content_width + HORIZONTAL_PADDING * 2)
	self.handles_mouse_input = true
	self:setSize(width, large and LARGE_HEIGHT or SMALL_HEIGHT)
end

---@return number
function FooterButton:getContentWidth()
	local text_width = self.text and self.font:getWidth(self.text) or 0
	local icon_width = self.icon and self.icon:getWidth() or 0
	local gap = self.text and self.icon and self.gap or 0
	return text_width + icon_width + gap
end

---@param old_x number
---@param old_y number
---@param old_width number
---@param old_height number
function FooterButton:onLayoutChanged(old_x, old_y, old_width, old_height)
	self:layoutContent()
end

function FooterButton:layoutContent()
	local text_width = self.text and self.font:getWidth(self.text) or 0
	local text_height = self.text and self.font:getHeight() or 0
	local icon_width, icon_height = 0, 0
	if self.icon then
		icon_width, icon_height = self.icon:getDimensions()
	end

	local gap = self.text and self.icon and self.gap or 0
	local x = (self.width - self:getContentWidth()) / 2

	if self.reverse then
		self.text_x = x
		self.icon_x = x + text_width + gap
	else
		self.icon_x = x
		self.text_x = x + icon_width + gap
	end
	self.text_y = (self.height - text_height) / 2
	self.icon_y = (self.height - icon_height) / 2
end

---@param e gui.HoverEvent
function FooterButton:onHover(e)
	Sounds.play("hover")
end

---@param e gui.MouseClickEvent
function FooterButton:onMouseClick(e)
	if e.button ~= 1 then return end
	if self.on_click then
		self.on_click()
	end
	Sounds.play("click")
	return true
end

local hover_bg = {1, 1, 1, 1}
local hover_content_color = {0, 0, 0, 1}

function FooterButton:draw()
	local bg = self.mouse_over and hover_bg or self.bg_color
	local content_color = self.mouse_over and hover_content_color or self.content_color
	Painter.snapToPixel()
	Painter.setColorTable(bg)

	local left_width = self.left:getWidth()
	local right_width = self.right:getWidth()
	local middle_width = self.width - left_width - right_width
	self.left:draw(0, 0)
	self.middle:draw(left_width, 0, 0, middle_width / self.middle:getWidth(), 1)
	self.right:draw(self.width - right_width, 0)

	Painter.setColorTable(content_color)
	if self.text then
		love.graphics.setFont(self.font)
		love.graphics.print(self.text, self.text_x, self.text_y)
	end
	if self.icon then
		self.icon:draw(self.icon_x, self.icon_y)
	end
end

return FooterButton
