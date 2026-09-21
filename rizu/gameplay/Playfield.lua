local class = require("class")
local AimPlayfield = require("rizu.gameplay.views.AimPlayfield")
local CatchPlayfield = require("rizu.gameplay.views.CatchPlayfield")
local TaikoPlayfield = require("rizu.gameplay.views.TaikoPlayfield")
local SdvxPlayfield = require("rizu.gameplay.views.SdvxPlayfield")

---@class rizu.gameplay.Playfield
---@operator call: rizu.gameplay.Playfield
---@field aim rizu.gameplay.views.AimPlayfield
---@field catch rizu.gameplay.views.CatchPlayfield
---@field taiko rizu.gameplay.views.TaikoPlayfield
---@field sdvx rizu.gameplay.views.SdvxPlayfield
---@field renderer rizu.gameplay.views.AimPlayfield|rizu.gameplay.views.CatchPlayfield|rizu.gameplay.views.TaikoPlayfield|rizu.gameplay.views.SdvxPlayfield?
local Playfield = class()

---@param game sphere.GameController
function Playfield:new(game)
	self.game = game
	self.aim = AimPlayfield(game)
	self.catch = CatchPlayfield(game)
	self.taiko = TaikoPlayfield(game)
	self.sdvx = SdvxPlayfield(game)
	self:refresh()
end

-- Selects the renderer from the gameplay engine. Consumers do not need to
-- know which native mode is active.
function Playfield:refresh()
	local engine = self.game.rhythm_engine
	local previous = self.renderer
	if engine and engine.aim_rules then self.renderer = self.aim
	elseif engine and engine.catch_rules then self.renderer = self.catch
	elseif engine and engine.taiko_rules then self.renderer = self.taiko
	elseif engine and engine.sdvx_rules then self.renderer = self.sdvx
	else self.renderer = nil end
	if previous and previous ~= self.renderer then previous:unload() end
	if self.renderer then self.renderer:load() end
end

---@return boolean
function Playfield:isExperimental()
	return self.renderer ~= nil
end

---@return boolean
function Playfield:usesPointer()
	local engine = self.game.rhythm_engine
	return not not (engine and engine.aim_rules)
end

---@param width number Gameplay viewport width in drawable pixels
---@param height number Gameplay viewport height in drawable pixels
---@param transform love.Transform Maps viewport coordinates to drawable pixels
function Playfield:draw(width, height, transform)
	if self.renderer then
		self.renderer:draw(width, height, transform)
	end
end

---@param x number Window x coordinate in drawable pixels
---@param y number Window y coordinate in drawable pixels
---@param width number Gameplay viewport width in drawable pixels
---@param height number Gameplay viewport height in drawable pixels
---@param transform love.Transform Maps viewport coordinates to drawable pixels
---@return number
---@return number
function Playfield:toChart(x, y, width, height, transform)
	assert(self:usesPointer(), "Gameplay playfield does not use pointer input")
	return self.aim:toChart(x, y, width, height, transform)
end

return Playfield
