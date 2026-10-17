local ScoreView = require("rizu.skin.views.ScoreView")

local test = {}

local font = {
	getWidth = function(_, text) return #text * 8 end,
	getHeight = function() return 20 end,
}

---@param t testing.T
function test.displays_score_source_string_and_resizes(t)
	local score_source = {getScoreString = function() return "001234" end}
	local game = {rhythm_engine = {score_engine = {scoreSource = score_source}}}
	local view = ScoreView(font)
	view:load(game)

	t:eq(view.text, "001234")
	t:eq(view.width, 48)
	t:eq(view.height, 20)
	t:eq(view.anchor, "top_right")

	score_source.getScoreString = function() return "9" end
	view:update(0, game)
	t:eq(view.text, "9")
	t:eq(view.width, 8)
end

---@param t testing.T
function test.empty_when_score_source_is_missing(t)
	local view = ScoreView(font)
	view:update(0, {rhythm_engine = {score_engine = {}}})
	t:eq(view.text, "")
	t:eq(view.width, 0)
end

return test
