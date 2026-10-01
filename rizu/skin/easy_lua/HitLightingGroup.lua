local class = require("class")
local HitLighting = require("rizu.skin.easy_lua.HitLighting")

---@class rizu.skin.easy_lua.HitLightingGroup.Config
---@field effects (rizu.skin.easy_lua.HitLighting|rizu.skin.easy_lua.HitLighting.Config)[]

---@class rizu.skin.easy_lua.HitLightingGroup
---@operator call: rizu.skin.easy_lua.HitLightingGroup
---@field effects rizu.skin.easy_lua.HitLighting[]
local HitLightingGroup = class()

---@param config rizu.skin.easy_lua.HitLightingGroup.Config
function HitLightingGroup:new(config)
	assert(type(config) == "table" and type(config.effects) == "table" and #config.effects > 0,
		"hit lighting group needs non-empty effects")
	self.effects = {}
	for index, effect in ipairs(config.effects) do
		if HitLighting * effect then
			self.effects[index] = effect
		else
			self.effects[index] = HitLighting(effect)
		end
	end
end

function HitLightingGroup:trigger()
	for _, effect in ipairs(self.effects) do effect:trigger() end
end

---@param held boolean
function HitLightingGroup:setHeld(held)
	for _, effect in ipairs(self.effects) do effect:setHeld(held) end
end

---@param dt number
function HitLightingGroup:update(dt)
	for _, effect in ipairs(self.effects) do effect:update(dt) end
end

---@param x number
---@param y number
function HitLightingGroup:draw(x, y)
	for _, effect in ipairs(self.effects) do effect:draw(x, y) end
end

return HitLightingGroup
