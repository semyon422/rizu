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
		settings = Settings.createConfig(FakeFilesystem()),
		library = {chartplayAccuraciesRepo = {
			getAccuracies = function(_, chartplay_id)
				return chartplay_id == 1 and {
					{timings = 2304, subtimings = 0, accuracy = 0.5},
					{timings = 2190, subtimings = 1101, accuracy = 0.987654},
					{timings = 2180, subtimings = 1102, accuracy = 0.8},
					{timings = 2180, subtimings = 1101, accuracy = 0.95},
				} or {}
			end,
		}},
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

---@param format sea.ChartFormat?
---@param timings sea.Timings?
---@return rizu.api.Chart
local function chart(format, timings)
	local row = {}
	row.format = format
	row.chartmeta_timings = timings
	return row
end

---@param t testing.T
function test.auto_depends_on_the_chart_only(t)
	local scores, selector = createScores()
	local settings = selector.settings
	settings:setNumber(Settings.keys.timings.osu_score_version, 2)
	settings:setNumber(Settings.keys.timings.etternaj, 5)

	-- The chart's OD with score V1, whatever the player picked.
	local osu = assert(scores:getAccuracySystem(chart("osu", Timings("osuod", 8))))
	t:eq(osu:getName(), "osu!mania V1 OD8")
	-- StepMania files have no timings: J4.
	t:eq(assert(scores:getAccuracySystem(chart("stepmania"))):getName(), "Etterna J4")
	t:assert(assert(scores:getAccuracySystem(chart("sphere"))):isNormalscore())
	t:eq(scores:getAccuracySystem(chart()), nil)

	selector.chartview = chart("osu", Timings("osuod", 8))
	t:eq(scores:getAccuracy({id = 1} --[[@as any]]), "95.00%")
	selector.chartview = chart("stepmania")
	t:eq(scores:getAccuracy({id = 1} --[[@as any]]), "50.00%")
	-- Rizu: normalscore, which every score has, online ones too.
	selector.chartview = chart("sphere")
	selector.source = "online"
	t:eq(scores:getAccuracy({id = 1, accuracy = 0.021} --[[@as any]]), "21.00ms")
end

---@param t testing.T
function test.selected_accuracy_system(t)
	local scores, selector = createScores()
	local settings = selector.settings
	t:eq(scores:getSelectedAccuracySystem(), "auto")

	-- Not stored yet: still "auto".
	scores:setSelectedAccuracySystem("osuod:9:1")
	t:eq(scores:getSelectedAccuracySystem(), "auto")

	settings:setString(Settings.keys.scores.stored_accuracies, "auto,osuod:9:1")
	t:tdeq(scores:getAccuracySystems(), {"auto", "osuod:9:1"})
	t:eq(scores:getSelectedAccuracySystem(), "osuod:9:1")
	t:eq(assert(scores:getAccuracySystem(chart("stepmania"))).timings.data, 9)
	t:eq(scores:getAccuracy({id = 1} --[[@as any]]), "98.77%")
	t:eq(scores:getAccuracy({id = 2} --[[@as any]]), nil)

	selector.source = "online"
	t:eq(scores:getAccuracy({id = 1} --[[@as any]]), nil)
end

return test
