local ITaskContext = require("rizu.library.tasks.ITaskContext")

---@class rizu.library.FakeTaskContext: rizu.library.ITaskContext
---@operator call: rizu.library.FakeTaskContext
local FakeTaskContext = ITaskContext + {}

function FakeTaskContext:new()
	---@type table[]
	self.actions = {}
	---@type {[string]: chart.Chart[]}
	self.charts = {}
end

function FakeTaskContext:getChartsByHash(hash)
	table.insert(self.actions, {"getChartsByHash", hash})
	local res = self.charts[hash]
	if res then
		return res
	end
	return nil, "not found"
end

function FakeTaskContext:startStage(stage, total)
	table.insert(self.actions, {"startStage", stage, total})
end

function FakeTaskContext:advance(amount, label)
	table.insert(self.actions, {"advance", amount, label})
end

function FakeTaskContext:report(label)
	table.insert(self.actions, {"report", label})
end

function FakeTaskContext:finish()
	table.insert(self.actions, {"finish"})
end

function FakeTaskContext:checkProgress(stage, data)
	table.insert(self.actions, {"checkProgress", stage, data})
end

function FakeTaskContext:shouldStop()
	return false
end

function FakeTaskContext:addError(err)
	table.insert(self.actions, {"addError", err})
end

function FakeTaskContext:dbBegin()
	table.insert(self.actions, {"dbBegin"})
end

function FakeTaskContext:dbCommit()
	table.insert(self.actions, {"dbCommit"})
end

return FakeTaskContext
