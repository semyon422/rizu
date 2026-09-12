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

	for _, from in ipairs(encs) do
		local cd, err = iconv:open(self.to_enc, from)
		if cd then
			cds[#cds + 1] = cd
		else
			print(("EncodingConverter: could not open %s -> %s: %s"):format(
				from, self.to_enc, tostring(err)
			))
		end
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

	local converted
	for _, cd in ipairs(self.cds) do
		converted = cd:convert(s)
		if converted then
			local valid = utf8validate(converted)
			if valid == converted then
				return converted
			end
		end
	end

	return utf8validate(s)
end

return EncodingConverter
