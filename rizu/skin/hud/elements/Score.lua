local TextElement = require("rizu.skin.hud.elements.TextElement")
local Animations = require("rizu.skin.hud.Animations")

local fields = TextElement.text_fields

---@class rizu.skin.hud.elements.Score : rizu.skin.hud.elements.TextElement
---@operator call: rizu.skin.hud.elements.Score
---@field number_state rizu.skin.hud.Animations.NumberState
local Score = TextElement + {}

Score.label = "Score"
Score.defaults = {anchor = "top_right", origin = "top_right"}
Score.fields = {
	fields.font, fields.overlap, fields.color,
	{key = "digits", label = "Digits", min = 0, max = 12, step = 1, default = 0},
	{key = "animation", label = "Animation", type = "dropdown", options = Animations.names(Animations.number),
		default = "none"},
}

---@param values {[string]: any}?
---@param textures rizu.skin.SkinTextures
function Score:new(values, textures)
	self.number_state = {}
	TextElement.new(self, values, textures)
end

---@param context rizu.api.GameApi
function Score:load(context)
	self.number_state = {}
	TextElement.load(self, context)
end

---@param dt number
---@param context rizu.api.GameApi
function Score:update(dt, context)
	local _, _, shown = context.gameplay:getScore()
	if not shown then return self:setText("") end
	local state = self.number_state
	Animations.number[self.values.animation].update(state, dt, shown, 0.75, 0.5)
	local digits = self.values.digits --[[@as number]]
	self:setText(("%0" .. digits .. "d"):format(math.floor(state.value + 0.5)))
end

function Score:draw()
	self:drawText(self.values.color --[[@as number[] ]])
end

return Score
