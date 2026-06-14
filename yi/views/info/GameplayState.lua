local View = require("gui.View")
local Painter = require("yi.Painter")
local Colors = require("yi.Colors")
local ModifierEncoder = require("sphere.models.ModifierEncoder")
local ModifierModel = require("sphere.models.ModifierModel")

---@class yi.views.info.GameplayState : gui.View
---@operator call: yi.views.info.GameplayState
local GameplayState = View + {}

function GameplayState:new()
	View.new(self)
	self:setSize(300, Painter.getFontHeight(24) + Painter.getFontHeight(36))
end

function GameplayState:onScroll(e)
	-- TODO: change rate
end

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

local cs = {Colors.text, ""}
local gap = 10

---@param timings sea.Timings
---@param subtimings sea.Subtimings?
---@return string
local function formatScoreSystem(timings, subtimings)
	if timings.name == "sphere" then
		return "Normalscore V3"
	elseif timings.name == "simple" then
		return ("Simple %ims"):format(timings.data * 1000)
	elseif timings.name == "arbitrary" then
		return "Arbitrary"
	elseif timings.name == "quaver" then
		return "Quaver Standard"
	elseif timings.name == "osuod" then
		local version = 0
		local od = timings.data
		if subtimings then
			version = subtimings.data
		end
		return ("osu!mania V%i OD%g"):format(version, od)
	elseif timings.name == "etternaj" then
		return ("Etterna J%i"):format(timings.data)
	elseif timings.name == "bmsrank" then
		local d = timings.data
		if d == 0 then
			return "LR2 Easy"
		elseif d == 1 then
			return "LR2 Normal"
		elseif d == 2 then
			return "LR2 Hard"
		elseif d == 3 then
			return "LR2 Insane"
		end
	end

	return "Unknown score system"
end

---@param replay_base sea.ReplayBase
---@param time_rate_model sphere.TimeRateModel
function GameplayState:bind(replay_base, time_rate_model)
	local mods = getModifierString(replay_base.modifiers)
	mods = mods == "" and "No mods" or mods

	self.mods = mods
	self.rate = ("%0.02fx"):format(time_rate_model:get())
	self.score_system = formatScoreSystem(replay_base.timings, replay_base.subtimings)
end

local lg = love.graphics

function GameplayState:draw()
	local s24 = Painter.getFontHeight(24)

	Painter.setFontOutline(0.12)
	Painter.setFontThickness(0.45)
	Painter.setFontOutlineColor(Colors.text_shadow)

	Painter.beginTextDrawing()

	lg.setColor(Colors.text_muted)
	Painter.setFontSize(24)
	Painter.print("MODIFIERS")

	lg.setColor(1, 1, 1)
	Painter.setFontSize(36)
	Painter.print(self.mods, 0, s24)

	lg.setColor(Colors.accent)
	lg.translate(
		Painter.getFontWidth(self.mods, 36) + 10,
		self.height - s24
	)
	Painter.setFontSize(24)
	Painter.print(self.rate)

	lg.setColor(Colors.text_muted)
	lg.translate(Painter.getFontWidth(self.rate, 24) + 10, 0)
	Painter.print(self.score_system)

	Painter.endTextDrawing()
end

return GameplayState
