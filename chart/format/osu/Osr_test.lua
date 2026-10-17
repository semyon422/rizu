local Osr = require("chart.format.osu.Osr")

local test = {}

---@param t testing.T
function test.mania_encode_decode(t)
	local osr = Osr()

	local mania_events = {
		{-1000, 1, true},
		{-500, 2, true},
		{0, 1, false},
		{500, 2, false},
	}

	osr:encodeManiaEvents(mania_events)

	t:tdeq(osr.events, {
		{-1000, 1, 19.17098, 0},
		{500, 3, 19.17098, 0},
		{500, 2, 19.17098, 0},
		{500, 0, 19.17098, 0},
		osr.last_event,
	})

	local _mania_events = osr:decodeManiaEvents()

	t:tdeq(_mania_events, mania_events)

	local data = osr:encode()

	local _osr = Osr()
	_osr:decode(data)

	t:tdeq(_osr, osr)
end

return test
