local class = require("class")
local table_util = require("table_util")
local ModifierModel = require("sphere.models.ModifierModel")
local ModifierRegistry = require("sphere.models.ModifierModel.ModifierRegistry")

---@class sphere.ModifierSelectModel
---@operator call: sphere.ModifierSelectModel
local ModifierSelectModel = class()

local Modifiers = ModifierRegistry.list

local OneUseModifiers = {
	"Custom",
	"WindUp",
	"NoScratch",
	"NoLongNote",
}

ModifierSelectModel.changed = false

---@param configurator rizu.gameplay.ReplayBaseConfigurator
function ModifierSelectModel:new(configurator)
	self.configurator = configurator
	self.modifierIndex = 1
	self.availableModifierIndex = 1

	self.addedModifiers = {}
	for _, name in ipairs(Modifiers) do
		self.addedModifiers[name] = 0
	end
end

---@return boolean
function ModifierSelectModel:isChanged()
	local changed = self.changed
	self.changed = false
	return changed
end

function ModifierSelectModel:change()
	self.changed = true
end

function ModifierSelectModel:updateAdded()
	for _, name in ipairs(Modifiers) do
		self.addedModifiers[name] = 0
	end
	for _, c in ipairs(self.configurator.modifiers) do
		local name = ModifierRegistry:getName(c.id)
		self.addedModifiers[name] = self.addedModifiers[name] + 1
	end
end

---@param modifier string
---@return boolean
function ModifierSelectModel:isAdded(modifier)
	return self.addedModifiers[modifier] > 0
end

---@param direction number
function ModifierSelectModel:scrollAvailableModifier(direction)
	if not Modifiers[self.availableModifierIndex + direction] then
		return
	end
	self.availableModifierIndex = self.availableModifierIndex + direction
end

---@param direction number
function ModifierSelectModel:scrollModifier(direction)
	local index = self.modifierIndex + direction
	if index < 1 or index > #self.configurator.modifiers + 1 then
		return
	end
	self.modifierIndex = index
end

---@param modifier string
---@return boolean
function ModifierSelectModel:isOneUse(modifier)
	return table_util.indexof(OneUseModifiers, modifier) ~= nil
end

---@param modifier string
---@return number
function ModifierSelectModel:getMinimalModifierIndex(modifier)
	local index = 1
	for _, ou_modifier in ipairs(OneUseModifiers) do
		if self:isAdded(ou_modifier) then
			index = index + 1
		end
		if modifier == ou_modifier then
			return index
		end
	end
	return index
end

---@param modifier string
function ModifierSelectModel:add(modifier)
	local minimalModifierIndex = self:getMinimalModifierIndex(modifier)
	self.modifierIndex = math.min(self.modifierIndex, #self.configurator.modifiers + 1)
	local index = math.max(self.modifierIndex, minimalModifierIndex)
	if self:isOneUse(modifier) then
		if self.addedModifiers[modifier] > 0 then
			return
		end
		index = minimalModifierIndex
	end
	ModifierModel:add(self.configurator.modifiers, modifier, index)
	self.modifierIndex = index + 1
	self.addedModifiers[modifier] = self.addedModifiers[modifier] + 1
	self:change()
end

---@param index number
function ModifierSelectModel:remove(index)
	local modifiers = self.configurator.modifiers
	local modifier = ModifierModel:remove(modifiers, index)
	if not modifiers[self.modifierIndex] then
		self.modifierIndex = math.max(self.modifierIndex - 1, 0)
	end
	if modifier then
		local name = ModifierRegistry:getName(modifier.id)
		self.addedModifiers[name] = self.addedModifiers[name] - 1
	end
	self:change()
end

return ModifierSelectModel
