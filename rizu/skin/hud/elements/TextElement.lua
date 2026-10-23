local HudElement = require("rizu.skin.hud.HudElement")
local BitmapFont = require("rizu.skin.BitmapFont")

local lg = love.graphics

---Base of elements that draw a number with a bitmap font. Its size is the size of the text.
---@class rizu.skin.hud.elements.TextElement : rizu.skin.hud.HudElement
---@operator call: rizu.skin.hud.elements.TextElement
---@field font rizu.skin.BitmapFont?
---@field text string
---@field draw_color number[]?
local TextElement = HudElement + {}

---@type {[string]: rizu.skin.hud.HudElement.Field}
TextElement.text_fields = {
	font = {key = "font", label = "Font", type = "bitmap_font", default = "score"},
	overlap = {key = "overlap", label = "Glyph overlap", min = -50, max = 50, step = 1, default = 0},
	color = {key = "color", label = "Color", type = "color", default = {1, 1, 1, 1}},
}

---@param values {[string]: any}?
---@param textures rizu.skin.SkinTextures
function TextElement:new(values, textures)
	self.text = ""
	self.font = nil
	HudElement.new(self, values, textures)
end

function TextElement:applyValues()
	HudElement.applyValues(self)
	if self.font then
		self.font.overlap = self.values.overlap --[[@as number]]
		self.font:unload()
		self:setText(self.text, true)
	end
end

---@return rizu.skin.SkinTextures.Asset[]
function TextElement:getAssets()
	return BitmapFont.getAssets(self.values.font --[[@as string]], HudElement.group)
end

---@param context rizu.api.GameApi
function TextElement:load(context)
	HudElement.load(self, context)
	self.font = BitmapFont(self.textures, self.values.font --[[@as string]], self.values.overlap --[[@as number]],
		HudElement.group)
	self:setText(self.text, true)
end

---@param context rizu.api.GameApi?
function TextElement:unload(context)
	self.font = nil
	HudElement.unload(self, context)
end

---@param text string
---@param force boolean? Measure again although the text is the same.
function TextElement:setText(text, force)
	if text == self.text and not force then return end
	self.text = text
	if self.font then self.width, self.height = self.font:measure(text) end
end

---@param color number[]
---@param alpha number?
---@param scale_x number?
---@param scale_y number? Stretch around the centre of the text, for animations.
function TextElement:drawText(color, alpha, scale_x, scale_y)
	local font = self.font
	if not font or self.text == "" then return end
	local width, height = self.width, self.height
	lg.push()
	lg.translate(width / 2, height / 2)
	lg.scale(scale_x or 1, scale_y or 1)
	lg.translate(-width / 2, -height / 2)
	local draw_color = self.draw_color or {}
	self.draw_color = draw_color
	draw_color[1], draw_color[2], draw_color[3] = color[1], color[2], color[3]
	draw_color[4] = (color[4] or 1) * (alpha or 1)
	font:draw(self.text, 1, 0, width, draw_color)
	lg.pop()
end

return TextElement
