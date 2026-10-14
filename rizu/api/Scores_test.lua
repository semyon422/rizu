local Scores = require("rizu.api.Scores")

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
		chartplay = nil,
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

return test
