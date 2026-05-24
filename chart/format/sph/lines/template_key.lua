local template_key = {}

local base = 85
template_key.base = base

local a_z, A_Z = {}, {}

local a_byte, A_byte = ("a"):byte(), ("A"):byte()
for i = 1, 26 do
	table.insert(a_z, string.char(a_byte + i - 1))
	table.insert(A_Z, string.char(A_byte + i - 1))
end

-- https://rfc.zeromq.org/spec/32/
local chars = "0123456789" .. table.concat(a_z) .. table.concat(A_Z) .. ".-:+=^!/*?&<>()[]{}@%$#"
assert(#chars == template_key.base)

---@type {[string]: integer}
local char_index = {}
for i = 1, base do
	char_index[chars:sub(i, i)] = i
end

local width = 2

---@param s string
---@return string
local function lead_zeroes(s)
	local zero = chars:sub(1, 1)
	return zero:rep(width - #s) .. s
end

---@param n number
---@return string
function template_key.encode(n)
	assert(n >= 0 and n < base ^ width)

	local out = {}

	repeat
		local _n = n % base
		n = (n - _n) / base
		table.insert(out, 1, chars:sub(_n + 1, _n + 1))
	until n == 0

	return lead_zeroes(table.concat(out))
end

---@param s string
---@return number
function template_key.decode(s)
	local out = 0

	for i = 1, #s do
		local c = s:sub(i, i)
		out = out + (char_index[c] - 1) * base ^ (#s - i)
	end

	return out
end

-- tests

local values = {
	{0, "00"},
	{1, "01"},
	{template_key.base - 1, "0#"},
	{template_key.base, "10"},
	{template_key.base ^ 2 - 2, "#$"},
	{template_key.base ^ 2 - 1, "##"},
}

for _, d in ipairs(values) do
	assert(template_key.encode(d[1]) == d[2])
	assert(template_key.decode(d[2]) == d[1])
end

return template_key
