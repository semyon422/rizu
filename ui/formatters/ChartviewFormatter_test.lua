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

return test
