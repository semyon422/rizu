local BaseButton = require("ui.base.Button")
local Colors = require("yi.Colors")
local Color = require("yi.Color")

---@class yi.TabButtonParams
---@field atlas love.Image
---@field pixel love.Quad
---@field tab love.Quad
---@field tab_outline love.Quad?
---@field font love.Font
---@field text string?
---@field text_color number[]?
---@field active_text_color number[]?
---@field inactive_text_color number[]?
---@field active_image_color number[]?
---@field inactive_image_color number[]?
---@field line_width number?
---@field text_padding_x number?
---@field active boolean?
---@field on_click fun(button: yi.TabButton)?

---@class yi.TabButton : ui.Button
---@overload fun(params: yi.TabButtonParams): yi.TabButton
---@field atlas love.Image
---@field pixel love.Quad
---@field tab love.Quad
---@field tab_outline love.Quad?
---@field font love.Font
---@field text string
---@field active_text_color number[]
---@field inactive_text_color number[]
---@field active_image_color number[]
---@field inactive_image_color number[]
---@field text_padding_x number
---@field active boolean
---@field on_click fun(button: yi.TabButton)?
---@field text_batch love.Text
---@field hover_t number
---@field hover_speed number
local TabButton = BaseButton + {}

---@param params yi.TabButtonParams
function TabButton:new(params)
	BaseButton.new(self)
	self.atlas = assert(params.atlas, "TabButton atlas is required")
	self.pixel = assert(params.pixel, "TabButton pixel quad is required")
	self.tab = assert(params.tab, "TabButton tab quad is required")
	self.tab_outline = params.tab_outline
	self.font = assert(params.font, "TabButton font is required")
	self.text = params.text or ""
	self.active_text_color = params.active_text_color or Colors.black
	self.inactive_text_color = params.inactive_text_color or params.text_color or Colors.white
	self.active_image_color = assert(params.active_image_color, "TabButton active image color is required")
	self.inactive_image_color = assert(params.inactive_image_color, "TabButton inactive image color is required")
	self.text_padding_x = params.text_padding_x or 24
	self.active = params.active or false
	self.on_click = params.on_click
	self.text_batch = love.graphics.newText(self.font, self.text)
	self.hover_t = 0
	self.hover_speed = 14
	self._hover_bg_color = {0, 0, 0, 1}
	self._bg_color = {0, 0, 0, 1}
	self._hover_text_color = {0, 0, 0, 1}
	self._text_color = {0, 0, 0, 1}
	self._outline_color = {0, 0, 0, 1}
	self._edge_color = {0, 0, 0, 1}

	local _, _, tab_w, tab_h = self.tab:getViewport()
	self:setSize(tab_w, tab_h)
end

---@param active boolean
function TabButton:setActive(active)
	self.active = active
end

---@param dt number
function TabButton:update(dt)
	local target = (self.mouse_over or self.focused) and (not self.active) and 1 or 0
	local blend_t = 1 - math.exp(-self.hover_speed * dt)
	self.hover_t = self.hover_t + (target - self.hover_t) * blend_t
end

---@return boolean
function TabButton:click()
	if self.on_click then
		self.on_click(self)
		return true
	end
	return false
end

function TabButton:draw()
	local lg = love.graphics
	local active = self.active
	local hovered = (self.mouse_over or self.focused) and (not active)
	local hover_t = self.hover_t
	local color = active and self.active_image_color or self.inactive_image_color
	local hover_bg_color = Color.scale_to(self._hover_bg_color, color, 1.1, 1.1)
	local bg_color = Color.mix_to(self._bg_color, color, hover_bg_color, hover_t)

	local text_color = active and self.active_text_color or self.inactive_text_color
	local hover_text_color = Color.scale_to(self._hover_text_color, text_color, 1.05, 1.2)
	text_color = Color.mix_to(self._text_color, text_color, hover_text_color, hover_t)
	local text_batch = self.text_batch
	local _, th = text_batch:getDimensions()
	local text_x = self.text_padding_x
	local text_y = (self.height - th) / 2

	lg.setColor(bg_color)
	lg.draw(self.atlas, self.tab)

	if self.tab_outline then
		local outline_color
		if active then
			outline_color = Colors.white_70
		else
			outline_color = Color.mix_to(self._outline_color, Colors.white_30, Colors.white_50, hover_t)
		end
		lg.setColor(outline_color)
		lg.draw(self.atlas, self.tab_outline)
	end

	if active then
		lg.setColor(Colors.cyan_400)
		lg.draw(self.atlas, self.pixel, 0, 0, 0, 6, self.height)
	elseif hovered or hover_t > 0.001 then
		lg.setColor(Color.mix_to(self._edge_color, Colors.white_10, Colors.white_30, hover_t))
		lg.draw(self.atlas, self.pixel, 0, 0, 0, 3 + hover_t * 2, self.height)
	end

	lg.setColor(text_color)
	lg.draw(text_batch, text_x, text_y)
end

return TabButton
