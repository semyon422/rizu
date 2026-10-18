local Barlines = require("chart.format.osu.Barlines")

local test = {}

---@param t testing.T
function test.regular(t)
	t:tdeq(Barlines:generate({{offset = 4500, beatLength = 500, signature = 4}}, 6500), {500, 2500, 4500, 6500})
	t:tdeq(Barlines:generate({{offset = 0, beatLength = 500, signature = 4, omitFirstBarLine = true}}, 4000), {2000, 4000})
	t:tdeq(Barlines:generate({}, 4000), {})
end

---@param t testing.T
function test.invalid_measure_lengths(t)
	for _, length in ipairs({0, -500, math.huge, -math.huge, 0 / 0}) do
		for _, offset in ipairs({0, 1000}) do
			t:tdeq(Barlines:generate({{offset = offset, beatLength = length, signature = 4}}, 5000), {})
		end
	end
end

---@param t testing.T
function test.valid_after_invalid(t)
	t:tdeq(Barlines:generate({
		{offset = 1000, beatLength = 0, signature = 4},
		{offset = 2000, beatLength = 500, signature = 4},
	}, 6000), {2000, 4000, 6000})
end

return test
