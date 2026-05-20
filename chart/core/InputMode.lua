local class = require("class")

---@class chart.InputMode
---@operator call: chart.InputMode
local InputMode = class()

---@param s string|table?
function InputMode:new(s)
	self:set(s)
end

---@param s string|table?
---@return chart.InputMode
function InputMode:set(s)
	if type(s) == "string" then
		for inputCount, inputType in s:gmatch("([0-9]+)([a-z]+)") do
			self[inputType] = tonumber(inputCount)
		end
		if s ~= tostring(self) then
			error(("invalid InputMode string (%s expected, got %s)"):format(tostring(self), s))
		end
	elseif type(s) == "table" then
		for inputType, inputCount in pairs(s) do
			self[inputType] = inputCount
		end
	end
	return self
end

---@param s string
---@return string?
---@return number?
function InputMode:splitInput(s)
	local inputType, inputIndex = s:match("^(.-)(%d+)$")
	if not inputType then
		return
	end
	return inputType, tonumber(inputIndex)
end

---@return number
function InputMode:getColumns()
	local columns = 0
	for _, inputCount in pairs(self) do
		columns = columns + inputCount
	end
	return columns
end

---@param a table
---@param b table
---@return boolean
local function sort(a, b)
	if a[2] ~= b[2] then
		return a[2] > b[2]
	end
	return a[1] < b[1]
end

---@return {[1]: string, [2]: integer}[]
function InputMode:getList()
	---@type {[1]: string, [2]: integer}[]
	local inputs = {}
	for inputType, inputCount in pairs(self) do
		table.insert(inputs, {inputType, inputCount})
	end
	table.sort(inputs, sort)
	return inputs
end

---@return chart.Column[]
function InputMode:getInputs()
	local inputs = self:getList()

	---@type ncdk2.Column[]
	local i2c = {}

	for i = 1, #inputs do
		for j = 1, inputs[i][2] do
			table.insert(i2c, inputs[i][1] .. j)
		end
	end

	return i2c
end

---@return {[chart.Column]: integer}
function InputMode:getInputMap()
	local inputs = self:getList()

	---@type {[ncdk2.Column]: integer}
	local c2i = {}

	local count = 0
	for i = 1, #inputs do
		for j = 1, inputs[i][2] do
			count = count + 1
			local column = inputs[i][1] .. j
			c2i[column] = count
		end
	end

	return c2i
end

---@param a chart.InputMode
---@return string
function InputMode.__tostring(a)
	local inputs = a:getList()

	for i = #inputs * 2, 1, -2 do
		local input = inputs[i / 2]
		inputs[i] = input[1]
		inputs[i - 1] = input[2]
	end

	return table.concat(inputs)
end

---@param a any
---@param b any
---@return string
function InputMode.__concat(a, b)
	return tostring(a) .. tostring(b)
end

---@param a chart.InputMode
---@param b chart.InputMode
---@return boolean
function InputMode.__eq(a, b)
	return tostring(a) == tostring(b)
end

---@param a chart.InputMode
---@param b chart.InputMode
---@return boolean
function InputMode.__le(a, b)
	for inputType, inputCount in pairs(a) do
		if b[inputType] ~= inputCount then
			return false
		end
	end
	return true
end

return InputMode
