local FakeFilesystem = require("fs.FakeFilesystem")
local Scores = require("rizu.api.Scores")
local Settings = require("rizu.config.Settings")
local Timings = require("sea.chart.Timings")

local test = {}

---@return rizu.api.Scores scores
---@return table selector
---@return fun(event: table) send
local function createScores()
	local listener
	local items = {{id = 1}, {id = 2}}
	local selector = {
		source = "local",
		onChanged = function(_, f) listener = f end,
		getScoreCount = function() return #items end,
		getScoreAt = function(_, i) return items[i] end,
		isScoreLoading = function() return false end,
		getScoreSource = function(self) return self.source end,
		setScoreSource = function(self, source) self.source = source end,
		pullScore = function() end,
		chartplay = nil,
		chartview = {chartmeta_mode = "mania", format = "osu", chartmeta_timings = Timings("sphere")},
		settings = Settings.createConfig(FakeFilesystem()),
	}
	return Scores(selector --[[@as any]], {} --[[@as any]]), selector, listener
end

---@param t testing.T
function test.list_and_source(t)
	local scores, selector, send = createScores()
	local loading
	scores:on("scores_changed", function(l) loading = l end)

	t:eq(scores:getCount(), 2)
	t:eq(scores:get(2).id, 2)
	t:eq(scores:get(3), nil)
	send({type = "score_items_changed", loading = true})
	t:eq(loading, true)
	send({type = "score_items_changed"})
	t:eq(loading, false)

	scores:setSource("online")
	t:eq(scores:getSource(), "online")
	t:eq(selector.source, "online")
end

---@param t testing.T
function test.load_selected_result_reports_why_it_failed(t)
	local scores, selector = createScores()
	local result
	scores:loadSelectedResult(function(ok, err) result = {ok, err} end)
	t:tdeq(result, {false})

	selector.chartplay = {id = 1}
	local scores_with_controller = Scores(selector --[[@as any]], {
		replayNoteChartAsync = function() error("replay is gone") end,
	} --[[@as any]])
	scores_with_controller:loadSelectedResult(function(ok, err) result = {ok, err} end)
	t:eq(result[1], false)
	t:assert(tostring(result[2]):find("replay is gone", 1, true))
end

---@param t testing.T
function test.normalscore_for_rizu_timings(t)
	local scores, selector = createScores()
	local score = {id = 1, accuracy = 0.021} --[[@as any]]
	t:eq(scores:getAccuracy(score), "21.00ms")
	t:tdeq({scores:getGrade(score)}, {"A", scores:getAccuracySystem()})

	local settings = selector.settings
	settings:setBoolean(Settings.keys.replay_base.auto_timings, false)
	settings:setChoice(Settings.keys.timings.system, "sphere")
	t:eq(scores:getAccuracy(score), "21.00ms", "Rizu timings are scored with normalscore")
end

---@param t testing.T
function test.picked_system_shows_the_rescored_accuracy(t)
	local scores, selector = createScores()
	local settings = selector.settings
	settings:setBoolean(Settings.keys.replay_base.auto_timings, false)
	settings:setNumber(Settings.keys.timings.osuod, 7)
	settings:setNumber(Settings.keys.timings.osu_score_version, 2)
	t:eq(assert(scores:getAccuracySystem()):getName(), "osu!mania V2 OD7")

	t:eq(scores:getAccuracy({id = 1, accuracy = 0.02, rescored_accuracy = 0.9512} --[[@as any]]), "95.12%")
	t:eq(scores:getAccuracy({id = 2, accuracy = 0.02} --[[@as any]]), nil, "no hits")
	t:eq(scores:getGrade({id = 1, accuracy = 0.02, rescored_accuracy = 0.9512} --[[@as any]]), "S")
	t:eq(scores:getGrade({id = 2, accuracy = 0.02} --[[@as any]]), nil)
end

---@param t testing.T
function test.auto_timings_show_the_chart_system(t)
	local scores, selector = createScores()
	selector.chartview.chartmeta_timings = Timings("osuod", 8)
	t:eq(assert(scores:getAccuracySystem()):getName(), "osu!mania V1 OD8")
	t:eq(scores:getAccuracy({id = 1, accuracy = 0.02, rescored_accuracy = 0.9512} --[[@as any]]), "95.12%")
end

---@param t testing.T
function test.normalscore_without_rescoring(t)
	local scores, selector = createScores()
	selector.chartview.chartmeta_timings = Timings("osuod", 8)
	local score = {id = 1, accuracy = 0.021, rescored_accuracy = 0.9512} --[[@as any]]

	selector.settings:setBoolean(Settings.keys.select.rescore, false)
	t:eq(scores:getAccuracySystem(), nil)
	t:eq(scores:getAccuracy(score), "21.00ms")
	selector.settings:setBoolean(Settings.keys.select.rescore, true)

	selector.source = "online"
	selector.settings:setChoice(Settings.keys.select.score_source, "online")
	t:eq(scores:getAccuracySystem(), nil, "the server has no hits")
	selector.settings:setChoice(Settings.keys.select.score_source, "local")

	selector.chartview.chartmeta_mode = "taiko"
	t:eq(scores:getAccuracySystem(), nil)
end

return test
