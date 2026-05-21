local class = require("class")
local table_util = require("table_util")
local InputMode = require("chart.core.InputMode")

---@param t integer[]
---@param j integer
---@param n integer
---@return integer[]
local function fill_range(t, j, n)
	table_util.clear(t)
	local c = 1
	for i = j, n do
		t[c] = i
		c = c + 1
	end
	return t
end

---@alias sea.ColumnsOrderTransform fun(c: integer, i: integer, ...: any): integer

---@class sea.ColumnsOrder
---@operator call: sea.ColumnsOrder
local ColumnsOrder = class()

---@param inputmode string|ncdk.InputMode
---@param values integer[]? valid values
function ColumnsOrder:new(inputmode, values)
	self.inputMode = InputMode(inputmode)
	self:import(values)
end

---@param values integer[]? valid values
function ColumnsOrder:import(values)
	local inputMode = self.inputMode
	local columns = inputMode:getColumns()
	local inputs = inputMode:getInputs()

	values = values or {}

	---@type {[chart.Column]: chart.Column}
	local map = {}
	for i = 1, columns do
		map[inputs[values[i] or i]] = inputs[i]
	end
	self.map = map
end

---@return integer[]?
function ColumnsOrder:export()
	local inputMode = self.inputMode
	local inputMap = inputMode:getInputMap()

	---@type integer[]
	local values = {}

	for a, b in pairs(self.map) do
		values[inputMap[b]] = assert(inputMap[a])
	end

	for i = 1, #values do
		if i ~= values[i] then
			return values
		end
	end

	return nil
end

---@return {[chart.Column]: chart.Column}
function ColumnsOrder:getInverseMap()
	return table_util.invert(self.map)
end

---@param co sea.ColumnsOrder
---@return boolean
function ColumnsOrder:equals(co)
	return table_util.equal(self.map, co.map)
end

---@param map {[chart.Column]: chart.Column}
---@return sea.ColumnsOrder
function ColumnsOrder:apply(map)
	for a, b in pairs(self.map) do
		self.map[a] = map[b] or b
	end
	return self
end

---@param f sea.ColumnsOrderTransform
---@param ... any
---@return sea.ColumnsOrder
function ColumnsOrder:transform(f, ...)
	local inputMode = self.inputMode
	---@cast inputMode +{[string]: integer}

	---@type {[chart.Column]: chart.Column}
	local map = {}

	for t, c in pairs(inputMode) do
		for i = 1, c do
			local _i = f(c, i, ...)
			map[t .. i] = t .. _i
		end
	end

	return self:apply(map)
end

---@type {[string]: sea.ColumnsOrderTransform}
local transforms = {
	mirror = function(c, i)
		return c - i + 1
	end,
	shift = function(c, i, v)
		return (i + v - 1) % c + 1
	end,
	bracketswap = function(c, i)
		if c <= 3 then
			return i
		elseif c == 4 then
			return i == 2 and 3 or i == 3 and 2 or i
		elseif c == 5 then
			return i < 3 and i % 2 + 1 or i > 3 and (i - 3) % 2 + 4 or i
		end

		local h = math.floor(c / 2)
		local q = math.ceil(h / 2)

		local function f(j)
			return (2 * (j % q)) % h + math.floor(j / q)
		end

		if i <= h then
			return f(i - 1) + 1
		elseif i > c - h then
			return c - f(c - i)
		end

		return i
	end,
	random = function(c, i, t, mode)
		local a, b = 1, c

		if mode == "left" then
			a, b = 1, math.floor(c / 2)
		elseif mode == "right" then
			a, b = math.ceil(c / 2) + 1, c
		end

		if i == 1 then
			fill_range(t, a, b)
		end

		if i >= a and i <= b then
			return table.remove(t, math.random(#t))
		end

		return i
	end
}

---@return string?
function ColumnsOrder:getName()
	local values = self:export()
	if not values then
		return
	end

	local inputmode = tostring(self.inputMode)
	if self:equals(ColumnsOrder(inputmode):mirror()) then
		return "mirror"
	elseif self:equals(ColumnsOrder(inputmode):bracketswap()) then
		return "bracketswap"
	end

	local columns = self.inputMode:getList()[1][2] -- largest count
	local a, b = math.ceil(-(columns - 1) / 2), math.ceil((columns - 1) / 2)
	for i = a, b do
		if self:equals(ColumnsOrder(inputmode):shift(i)) then
			return "shift " .. i
		end
	end

	return "custom"
end

---@return sea.ColumnsOrder
function ColumnsOrder:mirror()
	return self:transform(transforms.mirror)
end

---@param n integer
---@return sea.ColumnsOrder
function ColumnsOrder:shift(n)
	return self:transform(transforms.shift, n)
end

---@return sea.ColumnsOrder
function ColumnsOrder:bracketswap()
	return self:transform(transforms.bracketswap)
end

---@param mode "left"|"right"?
---@return sea.ColumnsOrder
function ColumnsOrder:random(mode)
	return self:transform(transforms.random, {}, mode)
end

return ColumnsOrder
