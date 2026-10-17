local TextLines = require("chart.format.sph.lines.TextLines")
local LinesCleaner = require("chart.format.sph.lines.LinesCleaner")

local test = {}

function test.decenc_1(t)
	local tl = TextLines()

	local lines_in = {
		"-",
		"- +1/2",
		"-",
		"- =0",
		"-",
		"- +1/2",
		"-",
		"-",
		"1000 ^ e1",
		"-",
		"- +1/2",
		"1000 ^",
		"-",
		"-",
		"- +1/2 ^",
		"1000 ^",
		"1000 ^",
		"-",
		"- =1",
		"-",
		"- +1/2",
		"-",
	}
	local lines_out = {
		"- =0",
		"-",
		"-",
		"1000 e1",
		"-",
		"1000 +1/2",
		"-",
		"1000",
		"1000 ^",
		"-",
		"- =1",
	}
	for _, line in ipairs(lines_in) do
		tl:decodeLine(line)
	end
	tl.lines = LinesCleaner:clean(tl.lines)

	t:eq(tl:encode(), table.concat(lines_out, "\n"))
end

return test
