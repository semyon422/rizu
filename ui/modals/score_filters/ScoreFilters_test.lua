local FakeLibrary = require("rizu.api.fake.FakeLibrary")
local FakeScores = require("rizu.api.fake.FakeScores")
local Localization = require("ui.localization.Localization")
local ScoreFilters = require("ui.modals.score_filters.ScoreFilters")
local Resources = require("ui.Resources")

local test = {}

---@param t testing.T
function test.recalculates_and_refreshes_scores_when_done(t)
	if not love.window.isOpen() then love.window.setMode(800, 600) end
	Resources.load()
	local library = FakeLibrary()
	local recalculated, refreshed = 0, 0
	library.recalculateAccuracies = function() recalculated = recalculated + 1 end
	local scores = FakeScores()
	scores.refresh = function() refreshed = refreshed + 1 end
	local modal = ScoreFilters(library, scores, {} --[[@as any]], function() end, Localization())

	local dropdown = modal.form.rows.children[1] --[[@as ui.views.form.Dropdown]]
	t:tdeq(dropdown.options, {"auto", "osuod:9:1", "etternaj:4"})
	t:eq(dropdown.format("auto"), "Chart's own timings")
	t:eq(dropdown.format("osuod:9:1"), "osu!mania V1 OD9")
	dropdown.on_change("etternaj:4")
	t:eq(scores:getSelectedAccuracySystem(), "etternaj:4")
	t:eq(refreshed, 1)
	refreshed = 0

	local row = modal.form.rows.children[2] --[[@as ui.views.form.ButtonRow]]
	row.buttons[1].on_click()
	t:eq(recalculated, 1)

	library:emit("cache_status_changed", {stage = "accuracies", current = 1, total = 2})
	t:eq(refreshed, 0)
	library:emit("cache_status_changed", {stage = "idle", current = 0, total = 0})
	t:eq(refreshed, 1)
	library:emit("cache_status_changed", {stage = "idle", current = 0, total = 0})
	t:eq(refreshed, 1)
end

return test
