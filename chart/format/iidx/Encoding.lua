local iconv = require("iconv")

---@class chart.iidx.Encoding
---@field _cache {[string]: string}
local Encoding = {_cache = {}}

---@param s string?
---@return string
function Encoding.strip_nul(s)
	s = s or ""
	local zero = s:find("\0", 1, true)
	if zero then
		return s:sub(1, zero - 1)
	end
	return s
end

---@param s string
---@return boolean
local function is_ascii(s)
	return not s:find("[\128-\255]")
end

---@param s string
---@param from string
---@param to string
---@return string
local function convert_iconv(s, from, to)
	s = Encoding.strip_nul(s)
	if s == "" or is_ascii(s) then
		return s
	end
	local key = from .. ">" .. to .. "\0" .. s
	if Encoding._cache[key] then
		return Encoding._cache[key]
	end

	---@type util.Iconv
	local cd = assert(iconv:open(to, from))
	local out, err = cd:convert(s)
	if not out and from == "CP932" then
		-- Fixed-width IIDX fields can cut the final multibyte character.
		cd:close()
		cd = assert(iconv:open(to, from))
		out, err = cd:convert(s:sub(1, -2))
	end
	cd:close()
	assert(out, err)
	Encoding._cache[key] = out
	return out
end

---@param s string
---@return string
function Encoding.cp932_to_utf8(s)
	return convert_iconv(s, "CP932", "UTF-8")
end

---@param s string
---@return string
function Encoding.utf16le_to_utf8(s)
	local out = {}
	for i = 1, #s - 1, 2 do
		local cp = s:byte(i) + s:byte(i + 1) * 256
		if cp == 0 then
			break
		elseif cp < 0x80 then
			out[#out + 1] = string.char(cp)
		elseif cp < 0x800 then
			out[#out + 1] = string.char(0xC0 + math.floor(cp / 0x40), 0x80 + (cp % 0x40))
		else
			out[#out + 1] = string.char(
				0xE0 + math.floor(cp / 0x1000),
				0x80 + (math.floor(cp / 0x40) % 0x40),
				0x80 + (cp % 0x40)
			)
		end
	end
	return table.concat(out)
end

return Encoding
