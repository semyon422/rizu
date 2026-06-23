local ffi = require("ffi")
local class = require("class")
local abs = math.abs
local floor = math.floor
local ceil = math.ceil
local min = math.min
local max = math.max

---@param a number
---@param b number
---@return number
local function gcd(a, b)
	a, b = abs(a), abs(b)
	a, b = max(a, b), min(a, b)

	if a == 1 or b == 1 or a == 0 or b == 0 then
		return 1
	end
	if a == b then
		return a
	end
	if a % b == 0 then
		return b
	end

	return gcd(b, a % b)
end

---@param n number
---@param d number
---@return number
---@return number
local function reduce(n, d)
	if n == 0 then
		return 0, 1
	end
	if n * d > 0 and n < 0 or d < 0 and n > 0 then
		n, d = -n, -d
	end

	local r = gcd(n, d)
	return n / r, d / r
end

-- https://stackoverflow.com/questions/4385580/finding-the-closest-integer-fraction-to-a-given-random-real-between-0-1-given

---@param R number
---@param limit number
---@param side "a"|"b"?
---@return number
---@return number
local function closest(R, limit, side)
	if R % 1 == 0 then
		return R, 1
	end

	local int, r = floor(R), R - floor(R)

	local a_num, a_den = 0, 1
	local b_num, b_den = 1, 1

	while true do
		local n, d = a_num + b_num, a_den + b_den

		if d > limit then
			if side == "a" then
				return a_num + int * a_den, a_den
			elseif side == "b" then
				return b_num + int * b_den, b_den
			end
			if r - a_num / a_den < b_num / b_den - r then
				return a_num + int * a_den, a_den
			else
				return b_num + int * b_den, b_den
			end
		end

		if n / d == r then
			return n + int * d, d
		end

		if n / d < r then
			a_num, a_den = n, d
		else
			b_num, b_den = n, d
		end
	end
end

local fractions = setmetatable({}, {__mode = "v"})

local ck = ffi.new("uint8_t[16]")
local cn, cd = ffi.cast("double*", ck), ffi.cast("double*", ck + 8)

---@param n number
---@param d number
---@return string
local function get_key(n, d)
	cn[0] = n
	cd[0] = d
	return ffi.string(ck, 16)
end

---@class chart.Fraction
---@operator call: chart.Fraction
---@operator add: chart.Fraction
---@operator sub: chart.Fraction
---@operator mul: chart.Fraction
---@operator div: chart.Fraction
---@operator mod: chart.Fraction
---@operator unm: chart.Fraction
---@operator concat: string
---@field [1] number
---@field [2] number
local Fraction = class()

---@param n number|table|chart.Fraction?
---@param d number|chart.Fraction?
---@param round any?
---@return chart.Fraction
function Fraction:new(n, d, round)
	local _n = type(n) == "number" and n or 0
	local _d = type(d) == "number" and d or 1
	if type(n) == "table" then
		_n, _d = n[1], _d * n[2]
	end
	if type(d) == "table" then
		_n, _d = _n * d[2], _d * d[1]
	end
	n, d = _n, _d

	if d % 1 ~= 0 or d == 0 then
		error(("invalid denominator: %0.20g"):format(d))
	end

	if round ~= nil then
		if round == "round" or round == true then
			n = floor(n * d + 0.5)
		elseif round == "floor" then
			n = floor(n * d)
		elseif round == "ceil" then
			n = ceil(n * d)
		elseif round == "closest" or round == false then
			n, d = closest(n, d)
		elseif round == "closest_gte" then
			n, d = closest(n, d, "b")
		elseif round == "closest_lte" then
			n, d = closest(n, d, "a")
		else
			error("invalid mode " .. tostring(round))
		end
	end

	if n % 1 ~= 0 then
		error(("invalid numerator: %0.20g"):format(n))
	end

	n, d = reduce(n, d)
	if d % 1 ~= 0 or d == 0 then
		error(("invalid denominator: %0.20g"):format(d))
	end
	if n % 1 ~= 0 then
		error(("invalid numerator: %0.20g"):format(n))
	end

	local key = get_key(n, d)
	local f = fractions[key]
	if f then
		return f
	end

	f = setmetatable({n, d}, Fraction)
	fractions[key] = f

	return f
end

getmetatable(Fraction).__call = Fraction.new

---@param n number|table
---@param d number?
---@param round boolean?
---@return chart.Fraction
local function fraction(n, d, round)
	if type(n) ~= "table" then
		return Fraction(n, d, round)
	elseif getmetatable(n) ~= Fraction then
		return Fraction(n[1], n[2])
	end
	return n
end

local temp_fraction = setmetatable({0, 1}, Fraction)

---@param n number|table?
---@return chart.Fraction
local function _fraction(n)
	if type(n) == "table" then
		return n
	end
	if n and n % 1 ~= 0 then
		error(("invalid numerator: %s"):format(n))
	end
	temp_fraction[1] = n or 0
	return temp_fraction
end

---@return number
function Fraction:floor()
	return floor(self[1] / self[2])
end

---@return number
function Fraction:ceil()
	return ceil(self[1] / self[2])
end

---@return number
function Fraction:tonumber()
	return self[1] / self[2]
end

---@param a chart.Fraction
---@return string
function Fraction.__tostring(a)
	local n, d = abs(a[1]), a[2]
	return ("%s%d.%d/%d"):format(a[1] < 0 and "-" or "", floor(n / d), n % d, d)
end

---@param a any
---@param b any
---@return string
function Fraction.__concat(a, b)
	return tostring(a) .. tostring(b)
end

---@param a chart.Fraction
---@param _ chart.Fraction
---@return chart.Fraction
function Fraction.__unm(a, _)
	return fraction(-a[1], a[2])
end

---@param a number|chart.Fraction
---@param b number|chart.Fraction
---@return number|chart.Fraction
function Fraction.__mod(a, b)
	---@diagnostic disable-next-line: param-type-mismatch
	return type(a) == "number" and a % b:tonumber() or a - b * (a / b):floor()
end

---@param a chart.Fraction
---@param b chart.Fraction
---@return chart.Fraction
local function add(a, b)
	return fraction(a[1] * b[2] + a[2] * b[1], a[2] * b[2])
end

---@param a chart.Fraction
---@param b chart.Fraction
---@return chart.Fraction
local function sub(a, b)
	return fraction(a[1] * b[2] - a[2] * b[1], a[2] * b[2])
end

---@param a chart.Fraction
---@param b chart.Fraction
---@return chart.Fraction
local function mul(a, b)
	return fraction(a[1] * b[1], a[2] * b[2])
end

---@param a chart.Fraction
---@param b chart.Fraction
---@return chart.Fraction
local function div(a, b)
	return fraction(a[1] * b[2], a[2] * b[1])
end

---@param a number|chart.Fraction?
---@param b number|chart.Fraction?
---@return number|chart.Fraction
function Fraction.__add(a, b)
	---@diagnostic disable-next-line: param-type-mismatch, need-check-nil
	return type(a) == "number" and a + b:tonumber() or add(a, _fraction(b))
end

---@param a number|chart.Fraction?
---@param b number|chart.Fraction?
---@return number|chart.Fraction
function Fraction.__sub(a, b)
	---@diagnostic disable-next-line: param-type-mismatch, need-check-nil
	return type(a) == "number" and a - b:tonumber() or sub(a, _fraction(b))
end

---@param a number|chart.Fraction?
---@param b number|chart.Fraction?
---@return number|chart.Fraction
function Fraction.__mul(a, b)
	---@diagnostic disable-next-line: param-type-mismatch, need-check-nil
	return type(a) == "number" and a * b:tonumber() or mul(a, _fraction(b))
end

---@param a number|chart.Fraction?
---@param b number|chart.Fraction?
---@return number|chart.Fraction
function Fraction.__div(a, b)
	---@diagnostic disable-next-line: param-type-mismatch, need-check-nil
	return type(a) == "number" and a / b:tonumber() or div(a, _fraction(b))
end

---@param a chart.Fraction
---@param b chart.Fraction
---@return boolean
function Fraction.__eq(a, b)
	return a[1] * b[2] == a[2] * b[1]
end

---@param a chart.Fraction
---@param b chart.Fraction
---@return boolean
function Fraction.__lt(a, b)
	return a[1] * b[2] < a[2] * b[1]
end

---@param a chart.Fraction
---@param b chart.Fraction
---@return boolean
function Fraction.__le(a, b)
	return a[1] * b[2] <= a[2] * b[1]
end

return Fraction
