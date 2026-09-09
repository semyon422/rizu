local EmptyWave = {}

---@param data string
---@return boolean
function EmptyWave.isEmpty(data)
	if data:sub(1, 4) ~= "RIFF" or data:sub(9, 12) ~= "WAVE" then return false end
	---@param offset integer
	---@return integer?
	local function uint32(offset)
		local a, b, c, d = data:byte(offset, offset + 3)
		if not d then return end
		return a + b * 256 + c * 65536 + d * 16777216
	end
	local size = uint32(5)
	if not size or size + 8 ~= #data then return false end
	local offset, format, found = 13, false, false
	while offset + 7 <= #data do
		local name = data:sub(offset, offset + 3)
		local length = assert(uint32(offset + 4))
		if offset + 7 + length > #data then return false end
		if name == "fmt " and length >= 16 then format = true end
		if name == "data" then
			if length > 0 then return false end
			found = true
		end
		offset = offset + 8 + length + length % 2
	end
	return format and found and offset == #data + 1
end

return EmptyWave
