local erfunc = {}

-- Abramowitz and Stegun. Handbook of Mathematical Functions. Formula 7.1.26 (page 299)

local o1 = 0.254829592
local o2 = -0.284496736
local o3 = 1.421413741
local o4 = -1.453152027
local o5 = 1.061405429
local p = 0.3275911

---@param x number
---@return number
function erfunc.erf(x)
	local t = 1 / (1 + p * math.abs(x))
	local y = 1 - (((((o5 * t + o4) * t) + o3) * t + o2) * t + o1) * t * math.exp(-x * x)
	return (x < 0 and -1 or 1) * y
end

-- libit http://libit.sourceforge.net/math_8c-source.html
-- scilab http://gitweb.scilab.org scilab/modules/special_functions/macros/erfinv.sci

-- https://stackoverflow.com/questions/27229371/inverse-error-function-in-c

local erf = erfunc.erf

local a1 = 0.88622692374517353
local a2 = -1.6601283962374516
local a3 = 0.92661860147244357
local a4 = -0.14110320437680104

local b1 = -2.13505380615258078
local b2 = 1.46060340345661088
local b3 = -0.33198239813321595
local b4 = 0.01197270616590528

local c1 = -1.994216456587148
local c2 = -1.87267416351196
local c3 = 3.60874665878559364
local c4 = 1.82365845766309853

local d1 = 3.74146294065960872
local d2 = 1.81848952562894617

---@param x number
---@return number
function erfunc.erfinv(x)
	local r
	local sign = 1

	if x < -1 or x > 1 then
		return 0 / 0
	elseif x == 0 then
		return 0
	elseif x < 0 then
		sign = -1
		x = -x
	end

	if x == 1 then
		return math.huge * sign
	end

	if x < 0.7 then
		local z = x * x
		r = x * (((a4 * z + a3) * z + a2) * z + a1) / ((((b4 * z + b3) * z + b2) * z + b1) * z + 1)
	else
		local z = math.sqrt(-math.log((1 - x) / 2))
		r = (((c4 * z + c3) * z + c2) * z + c1) / ((d2 * z + d1) * z + 1)
	end

	r = r * sign
	x = x * sign

	local c = 2 / math.sqrt(math.pi)
	r = r - (erf(r) - x) / (c * math.exp(-r * r))
	r = r - (erf(r) - x) / (c * math.exp(-r * r))

	return r
end

return erfunc
