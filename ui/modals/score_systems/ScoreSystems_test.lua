local FakeLibrary = require("rizu.api.fake.FakeLibrary")
local FakeScores = require("rizu.api.fake.FakeScores")
local Localization = require("ui.localization.Localization")
local Resources = require("ui.Resources")
local ScoreSystems = require("ui.modals.score_systems.ScoreSystems")

local test = {}

---@param modal ui.modals.score_systems.ScoreSystems
---@param text string
---@return fun()
local function findButton(modal, text)
	for _, row in ipairs(modal.form.rows.children) do
		---@cast row ui.views.form.ButtonRow
		for _, button in ipairs(row.buttons or {}) do
			if button.text == text then
				return button.on_click
			end
		end
	end
	error("no button " .. text)
end

---@param t testing.T
function test.adds_removes_and_recalculates(t)
	if not love.window.isOpen() then love.window.setMode(800, 600) end
	Resources.load()
	local library = FakeLibrary()
	local recalculated = 0
	library.recalculateAccuracies = function() recalculated = recalculated + 1 end
	local scores = FakeScores()
	local modal = ScoreSystems(scores, library, function() end, Localization())

	modal.system = "etternaj"
	modal.values.etternaj = 7
	findButton(modal, "Add")()
	t:tdeq(scores:getAccuracySystems(), {"auto", "osuod:9:1", "etternaj:4", "etternaj:7"})

	modal:update(0)
	local systems = modal.form.rows.children[2] --[[@as ui.modals.score_systems.ScoreSystems.Table]]
	t:eq(#systems.rows, 4)
	-- Auto stays.
	t:eq(systems:remove(1), false)
	t:eq(systems:remove(2), true)
	t:tdeq(scores:getAccuracySystems(), {"auto", "etternaj:4", "etternaj:7"})

	modal:update(0)
	systems = modal.form.rows.children[2] --[[@as ui.modals.score_systems.ScoreSystems.Table]]
	systems.cursor = 1
	t:eq(systems:onFormKeyDown({key = "down"} --[[@as any]]), true)
	t:eq(systems:onFormKeyDown({key = "delete"} --[[@as any]]), true)
	t:tdeq(scores:getAccuracySystems(), {"auto", "etternaj:7"})
	modal:update(0)
	systems = modal.form.rows.children[2] --[[@as ui.modals.score_systems.ScoreSystems.Table]]
	systems.cursor = 2
	-- The last row hands the key over to the form.
	t:eq(systems:onFormKeyDown({key = "down"} --[[@as any]]), false)

	findButton(modal, "Recalculate Accuracies")()
	t:eq(recalculated, 1)
end

---@param t testing.T
function test.refreshes_scores_when_recalculating_ends(t)
	if not love.window.isOpen() then love.window.setMode(800, 600) end
	Resources.load()
	local library = FakeLibrary()
	local scores = FakeScores()
	local refreshed = 0
	scores.refresh = function() refreshed = refreshed + 1 end
	ScoreSystems(scores, library, function() end, Localization())

	library:emit("cache_status_changed", {stage = "accuracies", current = 1, total = 2})
	t:eq(refreshed, 0)
	library:emit("cache_status_changed", {stage = "idle", current = 0, total = 0})
	t:eq(refreshed, 1)
	library:emit("cache_status_changed", {stage = "idle", current = 0, total = 0})
	t:eq(refreshed, 1)
end

return test
