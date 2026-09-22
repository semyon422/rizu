local IniParser = require("rizu.skin.IniParser")

local test = {}

---@param t testing.T
function test.parses_sections_and_values(t)
	local ini = IniParser.parse("\239\187\191[Global]\r\nFallbackNoteSkin=common\r\n\r\n[NoteDisplay]\r\n StartDrawingHoldBodyOffsetFromHead = 0\r\nStopDrawingHoldBodyOffsetFromTail=-32\r\n")

	t:eq(ini.Global.FallbackNoteSkin, "common")
	t:eq(ini.NoteDisplay.StartDrawingHoldBodyOffsetFromHead, "0")
	t:eq(ini.NoteDisplay.StopDrawingHoldBodyOffsetFromTail, "-32")
end

---@param t testing.T
function test.ignores_comments_and_joins_continued_lines(t)
	local ini = IniParser.parse("# comment\n; comment\n// comment\n-- comment\n[Section]\nValue=first\\\nsecond\n")

	t:eq(ini.Section.Value, "firstsecond")
end

return test
