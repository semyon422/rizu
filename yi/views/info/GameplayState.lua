local View = require("gui.View")
local Resources = require("yi.Resources")
local Colors = require("yi.Colors")
local ModifierEncoder = require("sphere.models.ModifierEncoder")
local ModifierModel = require("sphere.models.ModifierModel")

---@class yi.views.info.GameplayState : gui.View
---@operator call: yi.views.info.GameplayState
local GameplayState = View + {}

function GameplayState:new()
	View.new(self)
	self.small_font = Resources.getFont("bold", 24)
	self.large_font = Resources.getFont("bold", 36)
	self.small_batch = love.graphics.newTextBatch(self.small_font)
	self.large_batch = love.graphics.newTextBatch(self.large_font)

	self:setSize(200, self.small_font:getHeight() + self.large_font:getHeight())
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
function GameplayState:bind(replay_base)
	local mods = getModifierString(replay_base.modifiers)
	mods = mods == "" and "No mods" or mods

	local i = 0
	cs[1] = Colors.text_muted
	cs[2] = "MODIFIERS"
	self.small_batch:add(cs)

	cs[1] = Colors.text
	cs[2] = mods
	i = self.large_batch:add(cs, 0, self.small_font:getHeight())

	local x = self.large_batch:getWidth(i) + gap
	local y = self.height - self.small_font:getHeight() - 3
	cs[1] = Colors.accent
	cs[2] = ("%0.02fx"):format(replay_base.rate)
	i = self.small_batch:add(cs, x, y)

	x = x + self.small_batch:getWidth(i) + gap
	cs[1] = Colors.text_muted
	cs[2] = formatScoreSystem(replay_base.timings, replay_base.subtimings)
	self.small_batch:add(cs, x, y)
end

function GameplayState:draw()
	love.graphics.draw(self.small_batch)
	love.graphics.draw(self.large_batch)
end

return GameplayState
