local TextLines = require("chart.format.sph.lines.TextLines")

local test = {}

function test.decenc_1(t)
	local tl = TextLines()

	local lines = {
		"-",
		"0100 =0.01 +1/2 ^ v e0.5 x1.1,1.2 #1/4 :01 .02 // comment",
		"0000 + # : .",
	}
	for _, line in ipairs(lines) do
		tl:decodeLine(line)
	end

	t:eq(tl:encode(), table.concat(lines, "\n"))
end

return test
