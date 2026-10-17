local ScrollSpeed = require("rizu.gameplay.ScrollSpeed")

local test = {}

---@param t testing.T
function test.converts_osu_speed_to_canonical(t)
	t:eq(ScrollSpeed.toCanonical("osu", 24), 24 * 7 / 96)
	t:eq(ScrollSpeed.toDisplay("osu", 24 * 7 / 96), 24)
end

---@param t testing.T
function test.default_speed_is_canonical(t)
	t:eq(ScrollSpeed.toCanonical("default", 1.25), 1.25)
	t:eq(ScrollSpeed.toDisplay("default", 1.25), 1.25)
end

---@param t testing.T
function test.increase_uses_selected_scale(t)
	t:eq(ScrollSpeed.increase("osu", 1, 1), 15 * 7 / 96)
	t:eq(ScrollSpeed.increase("default", 1, 1), 1.05)
end

---@param t testing.T
function test.clamps_to_canonical_range(t)
	t:eq(ScrollSpeed.toCanonical("osu", 40), ScrollSpeed.canonical_max)
	t:eq(ScrollSpeed.toCanonical("default", 100), ScrollSpeed.canonical_max)
end

return test
