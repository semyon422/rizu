local Encoding = require("chart.format.iidx.Encoding")

local test = {}

---@param t testing.T
function test.utf16le_to_utf8(t)
	t:eq(Encoding.utf16le_to_utf8("A\0B\0\0\0"), "AB")
	t:eq(Encoding.utf16le_to_utf8("\xC6\x30\xB9\x30\xC8\x30\0\0"), "テスト")
end

return test
