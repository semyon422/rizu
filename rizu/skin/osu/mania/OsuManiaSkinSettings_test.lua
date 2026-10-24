local OsuManiaSkinSettings = require("rizu.skin.osu.mania.OsuManiaSkinSettings")

local test = {}

---@param t testing.T
function test.reads_the_section_of_the_key_count(t)
	local settings = OsuManiaSkinSettings.read({
		General = {Version = "latest"},
		Mania = {
			{Keys = "7", ColumnWidth = "99"},
			{keys = "4", columnwidth = "40, 20,200", ColumnSpacing = "-50,5", NoteBodyStyle1 = "0",
				Inputs4key = "key4,key3,key2,key1"},
		},
	}, {"key1", "key2", "key3", "key4"}, "4key")
	t:tdeq(settings.column_widths, {40, 20, 100, 30})
	t:tdeq(settings.column_spacings, {-20, 5, 0})
	t:tdeq(settings.note_body_styles, {"repeat_bottom", "stretch", "repeat_bottom", "repeat_bottom"})
	t:eq(settings.note_base_width, 20)
	t:eq(settings.inputs[1], "key4")
	t:eq(settings.input_map.key1, 4)
	t:tdeq(settings.column_suffixes, {[0] = "1", "2", "2", "1"})
end

---@param t testing.T
function test.bad_list_entries_read_as_zero_in_place(t)
	local settings = OsuManiaSkinSettings.read({Mania = {{Keys = "4", ColumnWidth = "40,x,,200",
		ColumnLineWidth = "1,oops,300", ColumnSpacing = "150", LightingNWidth = ""}}}, {"key1", "key2", "key3", "key4"}, "4key")
	t:tdeq(settings.column_widths, {40, 5, 5, 100})
	t:tdeq(settings.column_lines, {2, 0, 300, 2, 2})
	t:tdeq(settings.column_spacings, {150, 0, 0})
	t:tdeq(settings.lighting_n_widths, {0, 0, 0, 0})
end

---@param t testing.T
function test.split_stages_widen_the_middle_gap(t)
	local inputs = {}
	for index = 1, 10 do inputs[index] = "key" .. index end
	local settings = OsuManiaSkinSettings.read({Mania = {{Keys = "10", StageSeparation = "50"}}}, inputs, "10key")
	t:eq(settings.split_stages, true)
	t:eq(settings.column_spacings[5], 50)
	t:eq(settings.column_spacings[4], 0)
end

---@param t testing.T
function test.defaults_without_a_skin(t)
	local settings = OsuManiaSkinSettings.read(nil, {"key1", "key2"}, "2key")
	t:eq(settings.skin_hit_position, 402)
	t:eq(settings.default_note_body_style, "stretch")
	t:eq(settings.judgement_line, false)
	t:tdeq(OsuManiaSkinSettings.get_color({c = "255,0,51"}, "C", {}), {1, 0, 0.2, 1})
	local fallback = {}
	t:eq(OsuManiaSkinSettings.get_color({c = "255,x,0"}, "c", fallback), fallback)
end

return test
