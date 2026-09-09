local SdvxChart = require("chart.format.ksm.SdvxChart")
local test = {}

---@param t testing.T
function test.options_do_not_count_as_rows_and_tempo_changes_keep_time(t)
	local chart = SdvxChart([[title=fixture
t=120
o=125
m=music.ogg;effect.ogg
--
beat=3/4
fx-l=Gate;8
2000|10|0-
0000|10|:-
t=240
1000|20|o-
0000|00|--
--
]])
	t:eq(chart.offset, 0.125)
	t:eq(chart.audio_path, "music.ogg")
	t:eq(#chart.buttons, 4)
	t:eq(chart.buttons[1].kind, "hold")
	t:eq(chart.buttons[1].end_time, 0.375)
	t:eq(chart.buttons[2].end_time, 0.75)
	t:eq(chart.buttons[3].time, 0.75)
	t:eq(chart.buttons[4].lane, 5)
	t:eq(chart.tempos[2].time, 0.75)
	t:eq(chart.end_time, 1.125)
	local segment = chart.lasers[1].segments[1]
	t:eq(segment.time, 0)
	t:eq(segment.end_time, 0.75)
	t:eq(segment.from, 0)
	t:eq(segment.to, 1)
	t:eq(segment.slam, false)
end

---@param t testing.T
function test.laser_anchors_straights_and_reversals_are_not_collapsed(t)
	local chart = SdvxChart([[t=120
--
laserrange_l=2x
0000|00|0o
0000|00|AZ
0000|00|AZ
0000|00|o0
0000|00|0o
0000|00|--
--
]])
	t:eq(#chart.lasers, 2)
	t:eq(chart.lasers[1].extended, true)
	t:eq(chart.lasers[2].extended, false)
	local segments = chart.lasers[1].segments
	t:eq(#segments, 4)
	t:eq(segments[1].to, 0.2)
	t:eq(segments[2].from, segments[2].to)
	t:eq(segments[3].to, 1)
	t:eq(segments[4].to, 0)
end

---@param t testing.T
function test.slams_use_beat_threshold_and_remove_one_row_delay(t)
	local rows = {"0000|00|0-", "0000|00|o-", "0000|00|:-", "0000|00|:-", "0000|00|0-", "0000|00|--"}
	for _ = 7, 32 do rows[#rows + 1] = "0000|00|--" end
	local chart = SdvxChart("t=120\n--\n" .. table.concat(rows, "\n") .. "\n--\n")
	local segments = chart.lasers[1].segments
	t:eq(#segments, 2)
	t:eq(segments[1].slam, true)
	t:eq(segments[1].time, 0)
	t:eq(segments[1].end_time, 0)
	t:eq(segments[2].slam, false)
	t:eq(segments[2].time, 0)
	t:eq(segments[2].end_time, 0.25)
end

---@param t testing.T
function test.holds_end_at_next_chip_or_eof_and_final_newline_is_optional(t)
	local chart = SdvxChart("t=120\r\n--\r\n2000|A0|--\r\n1000|20|--\r\n0200|00|--")
	t:eq(#chart.buttons, 5)
	t:aeq(chart.buttons[1].end_time, 2 / 3, 1e-9)
	t:aeq(chart.buttons[2].end_time, 2 / 3, 1e-9)
	t:eq(chart.buttons[5].end_time, 2)
end

---@param t testing.T
function test.reject_invalid_data_instead_of_dropping_it(t)
	for _, source in ipairs({
		"t=0\n--\n1000|00|--", "t=nan\n--\n1000|00|--",
		"t=120\n--\n0000|00|:-", "t=120\n--\n0000|00|0-\n0000|00|--",
		"t=120\n--\n3000|00|--", "t=120\n--\n1000|00|--\nbeat=3/4\n0000|00|--",
		"t=120\n--\n1000|00|--\nt=200",
	}) do t:has_error(function() SdvxChart(source) end) end
end

---@param t testing.T
function test.consecutive_slams_keep_the_between_slam_span(t)
	local rows = {"0000|00|0-", "0000|00|o-", "0000|00|0-", "0000|00|--"}
	for _ = 5, 32 do rows[#rows + 1] = "0000|00|--" end
	local chart = SdvxChart("t=120\n--\n" .. table.concat(rows, "\n"))
	local segments = chart.lasers[1].segments
	t:eq(#segments, 3)
	t:eq(segments[1].slam, true)
	t:eq(segments[2].slam, false)
	t:eq(segments[2].from, 1)
	t:eq(segments[2].to, 1)
	t:eq(segments[2].time, 0)
	t:eq(segments[2].end_time, 0.0625)
	t:eq(segments[3].slam, true)
	t:eq(segments[3].time, 0.0625)
end

---@param t testing.T
function test.real_chart_extreme_meter_and_bpm_do_not_shift_following_notes(t)
	local chart = SdvxChart([[t=100-265
--
beat=1/192
t=16960
1000|00|--
--
beat=4/4
t=265
0100|00|--
--
]])
	t:aeq(chart.buttons[2].time, (4 / 192) * 60 / 16960, 1e-12)
	t:aeq(chart.end_time, (4 / 192) * 60 / 16960 + 4 * 60 / 265, 1e-12)
	t:eq(chart.tempos[1].bpm, 16960)
end

---@param t testing.T
function test.stray_header_text_is_reported_but_note_rows_remain_strict(t)
	local chart = SdvxChart("t=120\n.jpg\n--\n1000|00|--")
	t:eq(#chart.warnings, 1)
	t:assert(chart.warnings[1]:find("line 2: .jpg", 1, true))
	t:eq(chart.buttons[1].time, 0)
	t:has_error(function() SdvxChart("t=120\n--\n.jpg\n1000|00|--") end)
end

return test
