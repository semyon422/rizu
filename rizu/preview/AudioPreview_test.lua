local AudioPreview = require("rizu.preview.AudioPreview")

local test = {}

---@param t testing.T
function test.encode_decode(t)
	local preview = AudioPreview()
	preview.samples = {"sample1.wav", "sample2.ogg", "dir/sample3.mp3"}
	preview.events = {
		{time = 0.0, sample_index = 1, duration = 0.5, volume = 1.0},
		{time = 1.0, sample_index = 2, duration = 1.2, volume = 0.8},
		{time = 2.5, sample_index = 3, duration = 0.1, volume = 0.5},
	}

	local data = preview:encode()
	t:assert(type(data) == "string")
	t:assert(#data > 0)

	local preview2 = AudioPreview()
	preview2:decode(data)

	t:eq(#preview2.samples, #preview.samples)
	for i = 1, #preview.samples do
		t:eq(preview2.samples[i], preview.samples[i])
	end

	t:eq(#preview2.events, #preview.events)
	for i = 1, #preview.events do
		local e1 = preview.events[i]
		local e2 = preview2.events[i]
		t:assert(math.abs(e2.time - e1.time) < 1e-6)
		t:eq(e2.sample_index, e1.sample_index)
		t:assert(math.abs(e2.duration - e1.duration) < 1e-6)
		-- volume is quantized to 1/255
		t:assert(math.abs(e2.volume - e1.volume) < 1 / 250)
	end
end

---@param t testing.T
function test.empty(t)
	local preview = AudioPreview()
	local data = preview:encode()

	local preview2 = AudioPreview()
	preview2:decode(data)

	t:eq(#preview2.samples, 0)
	t:eq(#preview2.events, 0)
end

---@param t testing.T
function test.getRange(t)
	local preview = AudioPreview()
	local min_time, max_time = preview:getRange()
	t:eq(min_time, 0)
	t:eq(max_time, 0)

	preview.events = {
		{time = 1.0, sample_index = 1, duration = 0.5, volume = 1.0},
		{time = 0.5, sample_index = 2, duration = 1.2, volume = 0.8},
		{time = 2.5, sample_index = 3, duration = 0.1, volume = 0.5},
	}

	min_time, max_time = preview:getRange()
	t:eq(min_time, 0.5)
	t:eq(max_time, 2.6)

	-- Sample at negative time
	preview.events = {
		{time = -1.0, sample_index = 1, duration = 0.5, volume = 1.0},
		{time = 1.0, sample_index = 2, duration = 0.5, volume = 1.0},
	}
	min_time, max_time = preview:getRange()
	t:eq(min_time, -1.0)
	t:eq(max_time, 1.5)

	-- All audio < 0
	preview.events = {
		{time = -5.0, sample_index = 1, duration = 1.0, volume = 1.0},
		{time = -2.0, sample_index = 2, duration = 0.5, volume = 1.0},
	}
	min_time, max_time = preview:getRange()
	t:eq(min_time, -5.0)
	t:eq(max_time, -1.5)
end

return test
