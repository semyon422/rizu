local class = require("class")

-- https://github.com/itgmania/itgmania/blob/release/src/MsdFile.cpp

---@class chart.stepmania.MsdFile
---@operator call: chart.stepmania.MsdFile
---@field values {[integer]: string[]}
local MsdFile = class()

function MsdFile:new()
	self.values = {}
end

---@param s string
function MsdFile:addParam(s)
	local value = self.values[#self.values]
	table.insert(value, s)
end

function MsdFile:addValue()
	table.insert(self.values, {})
end

function MsdFile:getNumValues()
	return #self.values
end

---@param val integer
function MsdFile:getNumParams(val)
	if val > self:getNumValues() then
		return 0
	end
	return #self.values[val]
end

---@param val integer
---@return string[]
function MsdFile:getValue(val)
	if val > self:getNumValues() then
		return {}
	end
	return self.values[val]
end

---@param val integer
---@param par integer
---@return string
function MsdFile:getParam(val, par)
	if val > self:getNumValues() or par > self:getNumParams(val) then
		return ""
	end
	return self.values[val][par]
end

---@param s string
---@param unescape boolean?
function MsdFile:read(s, unescape)
	local reading_value = false
	local i = 1
	---@type string[]
	local processed = {}
	local processed_len = -1
	while i <= #s do
		if s:sub(i, i) == "/" and s:sub(i + 1, i + 1) == "/" then  -- skip comments
			repeat
				i = i + 1
			until not (i <= #s and s:sub(i, i) ~= "\n")
			goto continue
		end
		if reading_value and s:sub(i, i) == "#" then
			local first_char = true
			local j = processed_len
			while j > 0 and processed[j] ~= "\r" and processed[j] ~= "\n" do
				if processed[j] == " " or processed[j] == "\t" then
					j = j - 1
					goto continue
				end
				first_char = false
				do break end
				::continue::
			end
			if not first_char then
				processed_len = processed_len + 1
				processed[processed_len] = s:sub(i, i)
				i = i + 1
				goto continue
			end
			processed_len = j
			while processed_len > 0 and
				processed[processed_len] == "\r" or processed[processed_len] == "\n" or
				processed[processed_len] == " " or processed[processed_len] == "\t"
			do
				processed_len = processed_len - 1
			end
			self:addParam(table.concat(processed):sub(1, processed_len))
			processed_len = 0
			reading_value = false
		end
		if not reading_value and s:sub(i, i) == "#" then
			self:addValue()
			reading_value = true
		end
		if not reading_value then
			if unescape and s:sub(i, i) == "\\" then
				i = i + 2
			else
				i = i + 1
			end
			goto continue
		end
		if processed_len ~= -1 and (s:sub(i, i) == ":" or s:sub(i, i) == ";") then
			self:addParam(table.concat(processed):sub(1, processed_len))
		end
		if s:sub(i, i) == "#" or s:sub(i, i) == ":" then
			i = i + 1
			processed_len = 0
			goto continue
		end
		if s:sub(i, i) == ";" then
			reading_value = false
			i = i + 1
			goto continue
		end
		if s:sub(i, i) == "\\" and i <= #s then
			if unescape then
				i = i + 1
			else
				processed_len = processed_len + 1
				processed[processed_len] = s:sub(i, i)
				i = i + 1
			end
		end
		if i <= #s then
			processed_len = processed_len + 1
			processed[processed_len] = s:sub(i, i)
			i = i + 1
		end
		::continue::
	end
	if reading_value then
		self:addParam(table.concat(processed):sub(1, processed_len))
	end
end

return MsdFile
