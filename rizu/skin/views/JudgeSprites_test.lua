local JudgeSprites = require("rizu.skin.views.JudgeSprites")

local test = {}

for _, name in ipairs({"marvelous", "perfect", "pgreat", "great", "good", "okay", "bad", "meh", "boo", "poor", "miss"}) do
	JudgeSprites.images[name] = {getDimensions = function() return #name * 10, 20 end}
end

local cyan, yellow, green, blue, magenta, red = {0, 1, 1, 1}, {1, 1, 0, 1}, {0, 1, 0, 1}, {0.2, 0.4, 1, 1}, {1, 0, 1, 1}, {1, 0, 0, 1}

---@param t testing.T
function test.colors_follow_judge_index(t)
	local names = {"marvelous", "perfect", "great", "good", "bad", "miss"}
	for i, color in ipairs({cyan, yellow, green, blue, magenta, red}) do
		local _, c = JudgeSprites.get(names, i)
		t:tdeq(c, color)
	end
end

---@param t testing.T
function test.named_sprite_wins_and_missing_name_falls_back_by_index(t)
	local names = {"perfect", "great", "good", "ok", "meh", "miss"}
	t:eq((JudgeSprites.get(names, 1)), JudgeSprites.images.perfect)
	t:eq((JudgeSprites.get(names, 4)), JudgeSprites.images.good)
end

---@param t testing.T
function test.last_judge_is_always_miss_and_extra_indexes_fall_back_to_miss(t)
	local image, color = JudgeSprites.get({"perfect", "good", "miss"}, 3)
	t:eq(image, JudgeSprites.images.miss)
	t:tdeq(color, red)
	local names = {"a", "b", "c", "d", "e", "f", "g", "h"}
	image, color = JudgeSprites.get(names, 7)
	t:eq(image, JudgeSprites.images.miss)
	t:tdeq(color, red)
end

return test
