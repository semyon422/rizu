local View = require("gui.View")
local ModifierEncoder = require("sphere.models.ModifierEncoder")
local ModifierModel = require("sphere.models.ModifierModel")
local Resources = require("ui.Resources")
local Colors = require("ui.Colors")

---@class ui.screens.song_select.GameplayModifiers : gui.View
---@operator call: ui.screens.song_select.GameplayModifiers
local GameplayModifiers = View + {}

---@param mods sea.Modifier[] | string
---@return string
local function getModifierString(mods)
	if type(mods) == "string" then
		mods = ModifierEncoder:decode(mods)
	end

	local results = {}
	for _, mod in pairs(mods) do
		local modifier = ModifierModel:getModifier(mod.id)

		if modifier then
			local modifierString, modifierSubString = modifier:getString(mod)
			local fullMod = modifierString .. (modifierSubString or "")
			table.insert(results, fullMod)
		end
	end

	return table.concat(results, " ")
end

function GameplayModifiers:new()
	View.new(self)
	self.font = Resources.getFont("regular", 24)
	self.mods = ""
	self:setSize(0, self.font:getHeight())
end

function GameplayModifiers:bind(replay_base)
	self.mods = getModifierString(replay_base.modifiers)
end

function GameplayModifiers:draw()
	love.graphics.setFont(self.font)
	love.graphics.print(self.mods, -self.font:getWidth(self.mods))
end

return GameplayModifiers
