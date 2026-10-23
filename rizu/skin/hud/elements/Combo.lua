local TextElement = require("rizu.skin.hud.elements.TextElement")
local Animations = require("rizu.skin.hud.Animations")

local fields = TextElement.text_fields

---@class rizu.skin.hud.elements.Combo : rizu.skin.hud.elements.TextElement
---@operator call: rizu.skin.hud.elements.Combo
---@field combo_state rizu.skin.hud.Animations.ComboState
local Combo = TextElement + {}

Combo.label = "Combo"
Combo.fields = {
	fields.font, fields.overlap, fields.color,
	{key = "break_color", label = "Break color", type = "color", default = {1, 0.035, 0.035, 1}},
	{key = "animation", label = "Animation", type = "dropdown", options = Animations.names(Animations.combo),
		default = "none"},
}

---@return rizu.skin.hud.Animations.ComboState
local function new_state()
	return {shown = 0, alpha = 0, scale_x = 1, scale_y = 1, breaking = false}
end

---@param values {[string]: any}?
---@param textures rizu.skin.SkinTextures
function Combo:new(values, textures)
	self.combo_state = new_state()
	TextElement.new(self, values, textures)
end

---@param context rizu.api.GameApi
function Combo:load(context)
	self.combo_state = new_state()
	TextElement.load(self, context)
end

---@param dt number
---@param context rizu.api.GameApi
function Combo:update(dt, context)
	local combo = context.gameplay:getCombo() or 0
	local state = self.combo_state
	Animations.combo[self.values.animation].update(state, dt, combo)
	self:setText(state.shown > 0 and tostring(state.shown) or "")
end

function Combo:draw()
	local state = self.combo_state
	if state.alpha <= 0 then return end
	local color = state.breaking and self.values.break_color or self.values.color
	self:drawText(color --[[@as number[] ]], state.alpha, state.scale_x, state.scale_y)
end

return Combo
