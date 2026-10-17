local class = require("class")

---@class chart.Interpolator
---@operator call: chart.Interpolator
local Interpolator = class()

---@generic T
---@param p T
---@return T
local function ident(p)
	return p
end

local function eq(p, _p, ext)
	return not ext(p):compare(ext(_p)) and not ext(_p):compare(ext(p))
end

local function lt(p, _p, ext)
	return ext(p):compare(ext(_p))
end

---@generic T
---@param list {compare: fun(self: T, p: T)}[]
---@param p {compare: fun(self: T, p: T)}
---@param ext (fun(p: T): T)?
---@return number
function Interpolator:getBaseIndex(list, p, ext)
	ext = ext or ident

	local low = 1
	local high = #list
	local ans = #list + 1
	while low <= high do
		local mid = math.floor((low + high) / 2)
		if not lt(list[mid], p, ext) then
			ans = mid
			high = mid - 1
		else
			low = mid + 1
		end
	end

	if ans > #list then
		return #list
	end

	if eq(list[ans], p, ext) then
		return ans
	end

	return math.max(1, ans - 1)
end

return Interpolator
