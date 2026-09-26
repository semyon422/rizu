local class = require("class")
local AimRenderer = require("rizu.skin.base.AimRenderer")
local FruitsRenderer = require("rizu.skin.base.FruitsRenderer")
local TaikoRenderer = require("rizu.skin.base.TaikoRenderer")
local SdvxPlayfield = require("rizu.gameplay.views.SdvxPlayfield")

---@class rizu.gameplay.Playfield
---@operator call: rizu.gameplay.Playfield
---@field aim rizu.skin.base.AimRenderer
---@field catch rizu.skin.base.FruitsRenderer
---@field taiko rizu.skin.base.TaikoRenderer
---@field sdvx rizu.gameplay.views.SdvxPlayfield
---@field renderer rizu.gameplay.views.PlayfieldRenderer?
local Playfield = class()

---@param game sphere.GameController
function Playfield:new(game)
	self.game = game
	self.aim = AimRenderer(game)
	self.catch = FruitsRenderer(game)
	self.taiko = TaikoRenderer(game)
	self.sdvx = SdvxPlayfield(game)
	self:refresh()
end

-- Selects the renderer from the gameplay engine. Consumers do not need to
-- know which native mode is active.
function Playfield:refresh()
	local engine = self.game.rhythm_engine
	local mode = engine and engine.chartmeta and engine.chartmeta.mode
	local previous = self.renderer
	if engine and (engine.aim_rules or mode == "osu") then self.renderer = self.aim
	elseif engine and (engine.catch_rules or mode == "catch") then self.renderer = self.catch
	elseif engine and (engine.taiko_rules or mode == "taiko") then self.renderer = self.taiko
	elseif engine and (engine.sdvx_rules or mode == "sdvx") then self.renderer = self.sdvx
	elseif mode == "mania" then self.renderer = self.game.gameplayInteractor.mania_renderer
	else self.renderer = nil end
	if previous and previous ~= self.renderer then previous:unload() end
	if self.renderer then self.renderer:load() end
end

---@return boolean
function Playfield:usesDirectRenderer()
	return self.renderer ~= nil
end

---@return boolean
function Playfield:isExperimental()
	local engine = self.game.rhythm_engine
	if not engine then return false end
	local mode = engine.chartmeta and engine.chartmeta.mode
	return not not (
		engine.aim_rules or engine.catch_rules or engine.taiko_rules or engine.sdvx_rules
		or mode == "osu" or mode == "catch" or mode == "taiko" or mode == "sdvx"
	)
end

function Playfield:unload()
	if self.renderer then self.renderer:unload() end
	self.renderer = nil
end

---@return boolean
function Playfield:usesPointer()
	local engine = self.game.rhythm_engine
	return not not (engine and (engine.aim_rules or engine.chartmeta and engine.chartmeta.mode == "osu"))
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
	return self.renderer:toChart(x, y, width, height, transform)
end

return Playfield
