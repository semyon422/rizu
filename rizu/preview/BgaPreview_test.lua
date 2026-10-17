local BgaPreview = require("rizu.preview.BgaPreview")
local test = {}

---@param t testing.T
function test.encode_decode(t)
	local preview = BgaPreview()
	preview.samples = {"sample1.png", "sample2.mp4"}
	preview.events = {
		{time = 1.0, sample_index = 1, column = 10},
		{time = 2.0, sample_index = 2, column = 20},
	}

	local data = preview:encode()
	t:assert(type(data) == "string")

	local preview2 = BgaPreview()
	preview2:decode(data)

	t:eq(#preview2.samples, 2)
	t:eq(preview2.samples[1], "sample1.png")
	t:eq(preview2.samples[2], "sample2.mp4")

	t:eq(#preview2.events, 2)
	t:eq(preview2.events[1].time, 1.0)
	t:eq(preview2.events[1].sample_index, 1)
	t:eq(preview2.events[1].column, 10)
	t:eq(preview2.events[2].time, 2.0)
	t:eq(preview2.events[2].sample_index, 2)
	t:eq(preview2.events[2].column, 20)
end

return test
