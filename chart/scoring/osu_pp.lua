local osu_pp = {}

local curve = {[0] = 0, 0, 0, 0, 0, 0, 0.3, 0.55, 0.75, 0.9, 1}
local n = #curve
assert(n == 10)

---@param x number
---@return number
local function score_mul(x)
	if x <= 0 or x >= 1 then
		return x
	end
	local a = math.floor(x * n)
	return (x * n - a) * (curve[a + 1] - curve[a]) + curve[a]
end

assert(score_mul(0.75) == 0.6500000000000000222)

---@param score number [0, 1]
---@param stars number
---@param notes integer
---@return number
function osu_pp.strain(score, stars, notes)
	local strain = (5 * math.max(1, stars / 0.2) - 4) ^ 2.2 / 135
	strain = strain * (1 + 0.1 * math.min(1, notes / 1500))
	strain = strain * score_mul(score)

	return strain
end

---@param score number [0, 1]
---@param stars number
---@param notes integer
---@param od number
---@return number
function osu_pp.calc(score, stars, notes, od)
	score = math.min(math.max(score, 0), 1)

	local strain = osu_pp.strain(score, stars, notes)
	local acc = 0.02 * od * strain * (math.max(0, (score - 0.96) / 0.04)) ^ 1.1

	return (strain ^ 1.1 + acc ^ 1.1) ^ (1 / 1.1) * 0.8
end

---@param score number [0, 1]
---@param stars number
---@param notes integer
---@return number
function osu_pp.calc_no_acc(score, stars, notes)
	score = math.min(math.max(score, 0), 1)
	return osu_pp.strain(score, stars, notes) * 0.8
end

assert(osu_pp.calc(0.961285, 11.39, 6552, 7) == 1527.6101513841094857)

return osu_pp
