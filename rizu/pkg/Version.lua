local class = require("class")
local table_util = require("table_util")
local string_util = require("string_util")

---@class rizu.Version
---@operator call: rizu.Version
local Version = class()

---@param ver_str string?
---@return rizu.Version
function Version:parse(ver_str)
	if not ver_str then
		return Version()
	end
	local num_strs = string_util.split(ver_str, ".")
	---@type integer[]
	local nums = {}
	for i, num_str in ipairs(num_strs) do
		nums[i] = tonumber(num_str)
	end
	return Version(nums)
end

function Version:__tostring()
	return table.concat(self, ".")
end

function Version.__eq(a, b)
	return table_util.equal(a, b)
end

function Version.__lt(a, b)
	for i = 1, math.max(#a, #b) do
		if (a[i] or 0) < (b[i] or 0) then
			return true
		end
	end
end

return Version
