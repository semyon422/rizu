local ChartviewFormatter = require("ui.formatters.ChartviewFormatter")

local test = {}

---@param t testing.T
function test.formats_chart_mode(t)
	local formatter = ChartviewFormatter({chartdiff_inputmode = "7key1scratch"}, {})
	t:eq(formatter:getMode(), "7K1S")

	formatter:setChartview({mode = "taiko"})
	t:eq(formatter:getMode(), "TAIKO")

	formatter:setChartview()
	t:eq(formatter:getMode(), "NO CHART")
end

function test.formats_difficulty_postfix(t)
	local diff_column = "osu_diff"
	local settings = {
		getChoice = function()
			return diff_column
		end,
	}
	local formatter = ChartviewFormatter({
		osu_diff = 1,
		msd_diff = 2,
		enps_diff = 3,
		user_diff = 4,
	}, settings)

	local postfixes = {
		osu_diff = "★",
		msd_diff = "MSD",
		enps_diff = "ENPS",
		user_diff = "USER",
	}
	for column, postfix in pairs(postfixes) do
		diff_column = column
		t:eq(formatter:getDifficulty().postfix, postfix)
	end
end

---@param t testing.T
function test.aim_hides_legacy_mania_difficulty(t)
	local formatter = ChartviewFormatter({inputmode = "1osu", chartdiff_inputmode = "4key", osu_diff = 12}, {})
	t:eq(formatter:getMode(), "AIM (EXPERIMENTAL)")
	t:eq(formatter:getDifficulty().value, "—")
	t:eq(formatter:getDifficulty().postfix, "EXPERIMENTAL")
end

return test
