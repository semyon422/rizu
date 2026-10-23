local TextElement = require("rizu.skin.hud.elements.TextElement")
local Animations = require("rizu.skin.hud.Animations")

local fields = TextElement.text_fields

---@class rizu.skin.hud.elements.Accuracy : rizu.skin.hud.elements.TextElement
---@operator call: rizu.skin.hud.elements.Accuracy
---@field number_state rizu.skin.hud.Animations.NumberState
local Accuracy = TextElement + {}

Accuracy.label = "Accuracy"
Accuracy.defaults = {anchor = "top_right", origin = "top_right"}
Accuracy.fields = {
	fields.font, fields.overlap, fields.color,
	{key = "decimals", label = "Decimals", min = 0, max = 4, step = 1, default = 2},
	{key = "animation", label = "Animation", type = "dropdown", options = Animations.names(Animations.number),
		default = "none"},
}

---@param values {[string]: any}?
---@param textures rizu.skin.SkinTextures
function Accuracy:new(values, textures)
	self.number_state = {}
	TextElement.new(self, values, textures)
end

---@param context rizu.api.GameApi
function Accuracy:load(context)
	self.number_state = {}
	TextElement.load(self, context)
end

---@param dt number
---@param context rizu.api.GameApi
function Accuracy:update(dt, context)
	local _, text, shown = context.gameplay:getAccuracy()
	if not shown or not text then return self:setText("") end
	local decimals = self.values.decimals --[[@as number]]
	local precision = 10 ^ decimals
	local state = self.number_state
	Animations.number[self.values.animation].update(state, dt, math.floor(shown * precision + 0.5) / precision,
		0.5, 0.5 / precision)
	-- Bitmap fonts draw "ms" for "=", as osu! does.
	local suffix = text:match("%%$") and "%" or text:match("ms$") and "=" or ""
	local width = decimals > 0 and decimals + 3 or 2
	self:setText(("%0" .. width .. "." .. decimals .. "f"):format(state.value) .. suffix)
end

function Accuracy:draw()
	self:drawText(self.values.color --[[@as number[] ]])
end

return Accuracy
