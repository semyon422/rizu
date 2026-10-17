local OsuSkinIni = require("rizu.skin.OsuSkinIni")

local test = {}

---@param t testing.T
function test.parses_skin_ini_sections_comments_and_repeated_mania(t)
	local skin_ini = OsuSkinIni.parse("\239\187\191" .. table.concat({
		"// header comment",
		"[General]",
		"Name: Example: Deluxe // trailing comment",
		"Author:  Mapper  ",
		"Name: Ignored duplicate",
		"[Colours]",
		"Combo1: 255, 128, 0",
		"[Mania]",
		"Keys: 4",
		"NoteImage0: notes/one // note comment",
		"[Mania] trailing text",
		"Keys: 7",
		"[Fonts]",
		"ScorePrefix: score",
	}, "\r\n"))

	t:eq(skin_ini.General.Name, "Example: Deluxe")
	t:eq(skin_ini.General.Author, "Mapper")
	t:eq(skin_ini.Colours.Combo1, "255, 128, 0")
	t:eq(skin_ini.Mania[1].Keys, "4")
	t:eq(skin_ini.Mania[1].NoteImage0, "notes/one")
	t:eq(skin_ini.Mania[2].Keys, "7")
	t:eq(skin_ini.Fonts.ScorePrefix, "score")
end

---@param t testing.T
function test.ignores_properties_without_a_section_key_or_value(t)
	local skin_ini = OsuSkinIni.parse(table.concat({
		"Name: Implicit General",
		"[General]",
		"missing delimiter",
		": no key",
		"Empty:",
		"// comment",
		"[broken",
		"Ignored: value",
		"[General]",
		"Valid: value",
	}, "\n"))

	t:eq(skin_ini.General.Name, "Implicit General")
	t:eq(skin_ini.General.Empty, "")
	t:eq(skin_ini.General.Valid, "value")
	t:eq(skin_ini.General.Ignored, nil)
end

return test
