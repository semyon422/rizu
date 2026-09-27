local AccuracyView = require("rizu.skin.views.AccuracyView")
local class = require("class")

local test = {}

local Font = class()
function Font:getWidth(text)
	return #text * 10
end
function Font:getHeight()
	return 24
end

---@param t testing.T
function test.displays_accuracy_source_string_and_tracks_text_width(t)
	local accuracy_source = {
		getAccuracyString = function() return "98.76%" end,
	}
	local game = {
		rhythm_engine = {
			score_engine = {accuracySource = accuracy_source},
		},
	}
	local view = AccuracyView(Font())
	view:load(game)

	t:eq(view.anchor, "top_right")

	t:eq(view.origin, "top_right")
	t:eq(view.text, "98.76%")
	t:eq(view.width, 60)
	t:eq(view.height, 24)
end

---@param t testing.T
function test.empty_when_score_engine_has_no_accuracy_source(t)
	local game = {rhythm_engine = {score_engine = {}}}
	local view = AccuracyView(Font())
	view:update(0, game)
	t:eq(view.text, "")
	t:eq(view.width, 0)
end

return test
