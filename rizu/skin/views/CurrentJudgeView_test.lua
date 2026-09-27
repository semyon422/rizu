local CurrentJudgeView = require("rizu.skin.views.CurrentJudgeView")

local test = {}

local font = {
	getWidth = function(_, text) return #text * 8 end,
	getHeight = function() return 20 end,
}

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
	local view = CurrentJudgeView(font, {duration = 1})
	view:load(game)
	view:update(0, game)

	t:eq(view.text, "GOOD")
	t:eq(view.width, 32)
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
	local view = CurrentJudgeView(font)
	view:update(0, {rhythm_engine = {score_engine = score_engine}})
	t:eq(view.text, "MISS")
end

---@param t testing.T
function test.hides_when_no_judgement_source(t)
	local view = CurrentJudgeView(font)
	view:update(0, {rhythm_engine = {score_engine = {sequence = {}}}})
	t:eq(view.text, "")
	t:eq(view.elapsed, view.duration)
end

return test
