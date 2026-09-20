local View = require("gui.View")
local AimPlayfield = require("rizu.gameplay.views.AimPlayfield")
local CatchPlayfield = require("rizu.gameplay.views.CatchPlayfield")
local TaikoPlayfield = require("rizu.gameplay.views.TaikoPlayfield")
local SdvxPlayfield = require("rizu.gameplay.views.SdvxPlayfield")

---@class rizu.gameplay.Playfield: gui.View
---@operator call: rizu.gameplay.Playfield
---@field aim rizu.gameplay.views.AimPlayfield
---@field catch rizu.gameplay.views.CatchPlayfield
---@field taiko rizu.gameplay.views.TaikoPlayfield
---@field sdvx rizu.gameplay.views.SdvxPlayfield
local Playfield = View + {}

---@param game sphere.GameController
function Playfield:new(game)
	View.new(self)
	self.game = game
	self.aim = self:add(AimPlayfield(game)):anchorFill(0, 0, 0, 0)
	self.catch = self:add(CatchPlayfield(game)):anchorFill(0, 0, 0, 0)
	self.taiko = self:add(TaikoPlayfield(game)):anchorFill(0, 0, 0, 0)
	self.sdvx = self:add(SdvxPlayfield(game)):anchorFill(0, 0, 0, 0)
	self:refresh()
end

-- Selects the renderer from the gameplay engine. Consumers do not need to
-- know which native mode is active.
function Playfield:refresh()
	local engine = self.game.rhythm_engine
	self.aim:setVisible(not not (engine and engine.aim_rules))
	self.catch:setVisible(not not (engine and engine.catch_rules))
	self.taiko:setVisible(not not (engine and engine.taiko_rules))
	self.sdvx:setVisible(not not (engine and engine.sdvx_rules))
end

---@return boolean
function Playfield:isExperimental()
	local engine = self.game.rhythm_engine
	return not not (engine and (engine.aim_rules or engine.catch_rules or engine.taiko_rules or engine.sdvx_rules))
end

---@return boolean
function Playfield:usesPointer()
	local engine = self.game.rhythm_engine
	return not not (engine and engine.aim_rules)
end

---@param x number
---@param y number
---@return number
---@return number
function Playfield:toChart(x, y)
	assert(self:usesPointer(), "Gameplay playfield does not use pointer input")
	return self.aim:toChart(x, y)
end

return Playfield
