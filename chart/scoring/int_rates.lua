--[[
	This module implements constraints for time rate stored in a database.
	All rates are stored as an integer to avoid floating points errors.
	All rates are stored with 0.001 precision.

	X rates are from 0.25 to 4 with 0.001 step
	Q rates are from -20 to 20 with 0.1 step
]]

local int_rates = {}

local size = 1000
local xi_min, xi_max = 250, 4000
local x_min, x_max = 0.25, 4

local q_size = 100
local q_min, q_max = -200, 200

function int_rates.encode(x)
	assert(x >= x_min, x)
	assert(x == int_rates.round(x))
	return math.floor(x * size + 0.5)
end

function int_rates.decode(xi)
	assert(xi >= xi_min, xi)
	assert(math.floor(xi) == xi)
	return xi / size
end

function int_rates.round(x)
	return math.floor(x * size + 0.5) / size
end

function int_rates.get_exp(x, qs)
	local _q = math.log(x, 2) * (qs or q_size)
	return math.floor(_q + 0.5)
end

function int_rates.is_q_rate(x, qs)
	qs = qs or q_size
	local exp = int_rates.get_exp(x, qs)
	return int_rates.round(2 ^ (exp / qs)) == x
end

for i = xi_min, xi_max do
	local x = i / size
	assert(int_rates.encode(int_rates.decode(i)) == i)
	assert(int_rates.decode(int_rates.encode(x)) == x)
end

for q = q_min, q_max do
	local x = 2 ^ (q / q_size)
	x = int_rates.round(x)
	local _x = int_rates.decode(int_rates.encode(x))
	local _q = int_rates.get_exp(_x)
	assert(_q == q)
end

return int_rates
