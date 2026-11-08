local PatternTask = require("rizu.library.tasks.PatternTask")
local FakeTaskContext = require("rizu.library.tasks.FakeTaskContext")
local FunctionTimer = require("time.FunctionTimer")

local test = {}
local timer = FunctionTimer(function()
	return 0
end)

---@param t testing.T
function test.compute_missing(t)
	local saved = {} ---@type string[]
	local repo = {
		getMissingChartdiffs = function()
			return {
				{hash = "a", inputmode = "4key"},
				{hash = "b", inputmode = "7key1scratch"},
				{hash = "c", inputmode = "5key"},
			}
		end,
		save = function(_, chartdiff)
			table.insert(saved, chartdiff.hash)
		end,
	} --[[@as any]]

	PatternTask(repo, FakeTaskContext(), timer):computeMissing()

	t:tdeq(saved, {"a", "b"})
end

---@param t testing.T
function test.nothing_to_do(t)
	local context = FakeTaskContext()
	local repo = {
		getMissingChartdiffs = function()
			return {}
		end,
	} --[[@as any]]

	PatternTask(repo, context, timer):computeMissing()

	t:eq(#context.actions, 0, "no stage is started")
end

return test
