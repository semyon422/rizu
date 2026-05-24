local odhp = {}

---@param od number
---@return integer
function odhp.od3(od)
	return math.floor(3 * od)
end

---@param x number
---@param n integer
---@return integer
function odhp.round_od_int(x, n)
	assert(n >= 3 and math.floor(n) == n)
	return math.max(math.floor(x * n), math.ceil(odhp.od3(x) / 3 * n))
end

---@param x number
---@param n integer
---@return number
function odhp.round_od(x, n)
	return odhp.round_od_int(x, n) / n
end

--- osu hp is too compicated, just round it down
---@param x number
---@param n integer
---@return integer
function odhp.round_hp_int(x, n)
	return math.floor(x * n)
end

---@param x number
---@param n integer
---@return number
function odhp.round_hp(x, n)
	return odhp.round_hp_int(x, n) / n
end

return odhp
