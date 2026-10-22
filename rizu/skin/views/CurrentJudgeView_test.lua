local CurrentJudgeView = require("rizu.skin.views.CurrentJudgeView")
local JudgeSprites = require("rizu.skin.views.JudgeSprites")

local test = {}

for _, name in ipairs({"marvelous", "perfect", "pgreat", "great", "good", "okay", "bad", "meh", "boo", "poor", "miss"}) do
	JudgeSprites.images[name] = {getDimensions = function() return #name * 10, 20 end}
end

---@param t testing.T
function test.displays_current_judge_and_fades_it_out(t)
	local score_engine = {
		judgesSource = {
			getKey = function() return "judges" end,
			getJudgeNames = function() return {"perfect", "good", "miss"} end,
		},
		sequence = {
			{judges = {judge_index = 2}},
		},
	}
	local game = {rhythm_engine = {score_engine = score_engine}}
	local view = CurrentJudgeView({duration = 1})
	view:load(game)
	view:update(0, game)

	t:eq(view.image, JudgeSprites.images.good)
	t:tdeq(view.color, {1, 1, 0, 1})
	t:eq(view.width, 20)
	t:eq(view.height, 10)
	t:eq(view.elapsed, 0)
	t:eq(view.anchor, "center")

	view:update(0.25, game)
	t:eq(view.elapsed, 0.25)
	view:update(1, game)
	t:eq(view.elapsed, 1)
end

---@param t testing.T
function test.maps_negative_miss_index_to_final_judgement(t)
	local score_engine = {
		judgesSource = {
			getKey = function() return "judges" end,
			getJudgeNames = function() return {"perfect", "good", "miss"} end,
		},
		sequence = {{judges = {judge_index = -1}}},
	}
	local view = CurrentJudgeView()
	view:update(0, {rhythm_engine = {score_engine = score_engine}})
	t:eq(view.image, JudgeSprites.images.miss)
	t:tdeq(view.color, {1, 0, 0, 1})
end

---@param t testing.T
function test.hides_when_no_judgement_source(t)
	local view = CurrentJudgeView()
	view:update(0, {rhythm_engine = {score_engine = {sequence = {}}}})
	t:eq(view.image, nil)
	t:eq(view.elapsed, view.duration)
end

---@param t testing.T
function test.scale_multiplies_sprite_size(t)
	local score_engine = {
		judgesSource = {
			getKey = function() return "judges" end,
			getJudgeNames = function() return {"perfect", "miss"} end,
		},
		sequence = {{judges = {judge_index = 1}}},
	}
	local view = CurrentJudgeView({scale = 1})
	view:update(0, {rhythm_engine = {score_engine = score_engine}})
	t:eq(view.width, 70)
	t:eq(view.height, 20)
end

return test
