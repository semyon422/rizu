local class = require("class")

---@class rizu.skin.osu.mania.OsuManiaBatchPlan
---@operator call: rizu.skin.osu.mania.OsuManiaBatchPlan
---@field groups {[string]: string}
local OsuManiaBatchPlan = class()

-- Asset discovery describes how an image is used. This table is the only place
-- that decides which users share an atlas and which ones remain standalone.
local GROUPS = {
	note = "playfield",
	key = "playfield",
	stage_hint = "playfield",
	lighting = "standalone",
	combo_font = "playfield",
	judgement = "playfield",
	score_font = "font",
	accuracy_font = "font",
	stage_decoration = "standalone",
	progress = "standalone",
	standalone = "standalone",
}

function OsuManiaBatchPlan:new()
	self.groups = {}
	for role, group in pairs(GROUPS) do self.groups[role] = group end
end

---@param role string
---@return string
function OsuManiaBatchPlan:getGroup(role)
	local group = self.groups[role]
	if type(group) ~= "string" then error("unknown osu!mania asset role: " .. tostring(role), 2) end
	return group
end

---@return {[string]: string}
function OsuManiaBatchPlan:getGroups()
	local groups = {} ---@type {[string]: string}
	for role, group in pairs(self.groups) do
		if type(group) == "string" then groups[role] = group end
	end
	return groups
end

---@param requests rizu.skin.osu.mania.OsuManiaSkinAssetFinder.Request[]
---@return rizu.skin.osu.OsuSkinGraphics.Asset[]
function OsuManiaBatchPlan:build(requests)
	local assets = {} ---@type rizu.skin.osu.OsuSkinGraphics.Asset[]

	for _, request in ipairs(requests) do
		local group = self:getGroup(request.role)
		assets[#assets + 1] = {
			name = request.name,
			fallback = request.fallback,
			animation = request.animation,
			group = group,
		}
	end
	return assets
end

return OsuManiaBatchPlan
