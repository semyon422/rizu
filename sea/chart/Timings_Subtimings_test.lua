local Timings = require("sea.chart.Timings")
local Subtimings = require("sea.chart.Subtimings")
local TimingValuesFactory = require("sea.chart.TimingValuesFactory")

local test = {}

---@param t testing.T
function test.timings(t)
	for i = -1, 3000 do
		t:eq(Timings.encode(Timings.decode(i)), i)
	end

	local unknown = Timings.decode(3000)
	t:eq(unknown.name, "unknown")
	t:eq(unknown.data, 3000)

	Timings("unknown", 1)
	Timings("arbitrary")
	Timings("sphere")
	Timings("simple")
	Timings("osuod", 8.1)
	Timings("etternaj", 4)
	Timings("quaver")
	Timings("bmsrank")
	Timings("iidx")

	t:eq(t:has_error(Timings, "unknown", 0.1), "invalid")
	t:eq(t:has_error(Timings, "arbitrary", 1), "invalid")
	t:eq(t:has_error(Timings, "sphere", 1), "invalid")
	t:eq(t:has_error(Timings, "simple", 0.1111), "invalid")
	t:eq(t:has_error(Timings, "osuod", 8.15), "invalid")
	t:eq(t:has_error(Timings, "etternaj", 0), "invalid")
	t:eq(t:has_error(Timings, "quaver", 1), "invalid")
	t:eq(t:has_error(Timings, "bmsrank", 5), "invalid")
	t:eq(t:has_error(Timings, "iidx", 1), "invalid")
end

---@param t testing.T
function test.subtimings(t)
	for i = -1, 3000 do
		t:eq(Subtimings.encode(Subtimings.decode(i)), i)
	end

	local unknown = Subtimings.decode(3000)
	t:eq(unknown.name, "unknown")
	t:eq(unknown.data, 3000)

	Subtimings("scorev", 1)

	t:eq(t:has_error(Subtimings, "unknown", 0.1), "invalid")
	t:eq(t:has_error(Subtimings, "scorev", 3), "invalid")
end

---@param t testing.T
function test.values(t)
	local factory = TimingValuesFactory()

	t:assert(factory:get(Timings("unknown")))
	t:tdeq({factory:get(Timings("arbitrary"))}, {nil, "undefined for arbitrary timings"})

	t:assert(factory:get(Timings("sphere")))
	t:assert(factory:get(Timings("simple", 0.100)))
	t:assert(factory:get(Timings("osuod", 8)))
	t:assert(factory:get(Timings("osuod", 8), Subtimings("scorev", 1)))
	t:assert(factory:get(Timings("etternaj", 4)))
	t:assert(factory:get(Timings("quaver")))
	t:assert(factory:get(Timings("bmsrank", 3)))
	t:assert(factory:get(Timings("iidx")))

	t:assert(not factory:get(Timings("sphere"), Subtimings("scorev", 1)))
	t:assert(not factory:get(Timings("simple", 0.100), Subtimings("scorev", 1)))
	t:assert(not factory:get(Timings("etternaj", 4), Subtimings("scorev", 1)))
	t:assert(not factory:get(Timings("quaver"), Subtimings("scorev", 1)))
	t:assert(not factory:get(Timings("bmsrank"), Subtimings("scorev", 1)))
	t:assert(not factory:get(Timings("iidx"), Subtimings("scorev", 1)))
end

return test
