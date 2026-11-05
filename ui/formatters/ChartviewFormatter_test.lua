local ChartviewFormatter = require("ui.formatters.ChartviewFormatter")

local test = {}

---@param t testing.T
function test.formats_chart_mode(t)
	local formatter = ChartviewFormatter({chartdiff_inputmode = "7key1scratch"}, {})
	t:eq(formatter:getMode(), "7K1S")
	t:eq(formatter:getMode("7key"), "7K")

	formatter:setChartview({mode = "taiko"})
	t:eq(formatter:getMode(), "TAIKO")

	formatter:setChartview()
	t:eq(formatter:getMode(), "NO CHART")
end

---@param t testing.T
function test.formats_iidx_difficulty_names(t)
	local formatter = ChartviewFormatter(nil, {})
	local names = {
		SPB = "Beginner SP",
		SPN = "Normal SP",
		SPH = "Hyper SP",
		SPA = "Another SP",
		SPL = "Leggendaria SP",
		DPB = "Beginner DP",
		DPN = "Normal DP",
		DPH = "Hyper DP",
		DPA = "Another DP",
		DPL = "Leggendaria DP",
	}

	for name, expected in pairs(names) do
		formatter:setChartview({format = "iidx", name = name})
		t:eq(formatter:getName(), expected)
	end

	formatter:setChartview({format = "osu", name = "SPN"})
	t:eq(formatter:getName(), "SPN")
	formatter:setChartview({format = "iidx", name = "Custom"})
	t:eq(formatter:getName(), "Custom")
end

function test.applies_time_rate_to_duration_and_tempo(t)
	local formatter = ChartviewFormatter({
		duration = 150,
		tempo = 120,
		tempo_min = 100,
		tempo_max = 140,
	}, {})
	formatter:setTimeRate(1.5)

	t:eq(formatter:getDuration(), "1:40")
	local tempo = formatter:getTempo()
	t:eq(tempo.avg, "180")
	t:eq(tempo.min, "150")
	t:eq(tempo.max, "210")
end

function test.formats_difficulty_postfix(t)
	local diff_column = "calc:osu"
	local settings = {
		getChoice = function()
			return diff_column
		end,
	}
	local formatter = ChartviewFormatter({
		osu_diff = 1,
		enps_diff = 3,
		difficulty = 4,
	}, settings)

	local postfixes = {
		["calc:osu"] = "★",
		["calc:enps"] = "ENPS",
		["calc:rizu"] = "RIZU",
	}
	for column, postfix in pairs(postfixes) do
		diff_column = column
		t:eq(formatter:getDifficulty().postfix, postfix)
	end
end

---@param t testing.T
function test.rizu_shows_4k_dan(t)
	local settings = {getChoice = function() return "calc:rizu" end}
	local formatter = ChartviewFormatter({difficulty = 28, chartdiff_inputmode = "4key"}, settings)
	t:eq(formatter:getDifficulty().postfix, "RIZU")
	t:eq(formatter:getDifficulty().dan, "Beta")
	formatter:setChartview({difficulty = 28, chartdiff_inputmode = "4key", long_notes_ratio = 0.5})
	t:eq(formatter:getDifficulty().dan, nil)
	formatter:setChartview({difficulty = 28, chartdiff_inputmode = "7key"})
	t:eq(formatter:getDifficulty().dan, "10th+")
	formatter:setChartview({difficulty = 28, chartdiff_inputmode = "8key"})
	t:eq(formatter:getDifficulty().dan, nil)
end

---@param t testing.T
function test.rizu_difficulty_is_colored_on_the_msd_scale(t)
	local settings = {getChoice = function() return "calc:rizu" end}
	local low = ChartviewFormatter({difficulty = 10, chartdiff_inputmode = "7key"}, settings):getDifficulty().color
	local high = ChartviewFormatter({difficulty = 35, chartdiff_inputmode = "7key"}, settings):getDifficulty().color
	t:assert(low[1] ~= 1 or low[2] ~= 1 or low[3] ~= 1, "not white")
	t:assert(low[1] ~= high[1] or low[2] ~= high[2] or low[3] ~= high[3], "harder is another color")
end

---@param t testing.T
function test.aim_hides_legacy_mania_difficulty(t)
	local formatter = ChartviewFormatter({chartmeta_mode = "osu", inputmode = "1osu", chartdiff_inputmode = "4key", osu_diff = 12}, {})
	t:eq(formatter:getMode(), "AIM (EXPERIMENTAL)")
	t:eq(formatter:getDifficulty().value, "—")
	t:eq(formatter:getDifficulty().postfix, "EXPERIMENTAL")
end

---@param t testing.T
function test.catch_hides_legacy_difficulty(t)
	local formatter = ChartviewFormatter({chartmeta_mode = "catch", inputmode = "1fruits", chartdiff_inputmode = "4key", osu_diff = 12}, {})
	t:eq(formatter:getMode(), "CATCH (EXPERIMENTAL)")
	t:eq(formatter:getDifficulty().value, "—")
end

---@param t testing.T
function test.taiko_has_native_mode_label(t)
	local formatter = ChartviewFormatter({chartmeta_mode = "taiko", inputmode = "1taiko", chartdiff_inputmode = "2key", osu_diff = 12}, {})
	t:eq(formatter:getMode(), "TAIKO (EXPERIMENTAL)")
	t:eq(formatter:getDifficulty().value, "—")
end

---@param t testing.T
function test.sdvx_masks_cached_directional_difficulty(t)
	local formatter = ChartviewFormatter({chartmeta_mode = "sdvx", format = "ksm", inputmode = "4bt2fx2laserleft2laserright", osu_diff = 12}, {})
	t:eq(formatter:getMode(), "SDVX (EXPERIMENTAL)")
	t:eq(formatter:getDifficulty().value, "—")
end

return test
