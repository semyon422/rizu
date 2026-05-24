local iconv = require("iconv")
local class = require("class")
local utf8validate = require("utf8validate")

---@class chart.EncodingConverter
---@operator call: chart.EncodingConverter
local EncodingConverter = class()

EncodingConverter.to_enc = "UTF-8"

---@param encs table
function EncodingConverter:new(encs)
	assert(#encs > 0)

	local cds = {}
	self.cds = cds

	for i, from in ipairs(encs) do
		cds[i] = iconv:open(self.to_enc, from)
    end
	-- cds[#cds + 1] = iconv:open(self.to_enc .. "//IGNORE", encs[1])
end

local Encodings = {
	{"UTF-8", "SHIFT-JIS"},
	{"UTF-8", "ISO-8859-1"},
	{"UTF-8", "CP932"},
	{"UTF-8", "EUC-KR"},
	{"UTF-8", "US-ASCII"},
	{"UTF-8", "CP1252"},
	{"UTF-8//IGNORE", "SHIFT-JIS"},
}

---@param s string
---@return string
function EncodingConverter:convert(s)
	if utf8validate(s) == s then
		return s
	end

	local valid
	for _, cd in ipairs(self.cds) do
		valid = cd:convert(s)
		if valid then break end
	end

	return utf8validate(valid or s)
end

return EncodingConverter
