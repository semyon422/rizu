local class = require("class")
local Observable = require("Observable")

---@class rizu.select.SelectionState
---@operator call: rizu.select.SelectionState
local SelectionState = class()

---@class rizu.select.SelectionLevel
---@field index integer
---@field id integer?

function SelectionState:new()
	---@type rizu.select.SelectionLevel[]
	self.levels = {
		{index = 1, id = nil}, -- Primary
		{index = 1, id = nil}, -- Secondary
	}
	---@type integer
	self.chartplayIndex = 1
	---@type integer?
	self.scoreId = nil

	self.onChanged = Observable()
end

---@param level integer
---@param index integer
---@param id integer?
function SelectionState:setSelection(level, index, id)
	local l = self.levels[level]
	if not l then
		self.levels[level] = {index = index, id = id}
		l = self.levels[level]
	elseif l.index == index and l.id == id then
		return
	end

	l.index = index
	l.id = id

	self.onChanged:send({type = "selection", level = level, index = index, id = id})
end

---@param index integer
---@param id integer?
function SelectionState:setScore(index, id)
	if self.chartplayIndex == index and self.scoreId == id then return end
	self.chartplayIndex = index
	self.scoreId = id
	self.onChanged:send({type = "score", index = index, id = id})
end

-- Getters
function SelectionState:getSelection(level) return self.levels[level] end
function SelectionState:getPrimary() return self.levels[1] end
function SelectionState:getSecondary() return self.levels[2] end

return SelectionState
