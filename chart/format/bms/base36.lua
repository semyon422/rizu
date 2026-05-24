local base36 = {}

local chars = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"

---@param n number
---@return string
function base36.tostring(n)
	local a = n % 36
	local b = (n - a) / 36 % 36
	return chars:sub(b + 1, b + 1) .. chars:sub(a + 1, a + 1)
end

assert(base36.tostring(0) == "00")
assert(base36.tostring(36 * 36 - 1) == "ZZ")

return base36
