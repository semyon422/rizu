local BatchProcessor = require("rizu.library.tasks.BatchProcessor")
local FunctionTimer = require("time.FunctionTimer")

local test = {}

---@param t testing.T
function test.computes_outside_batched_transactions(t)
	local in_transaction = false
	local begins = 0
	local commits = 0
	local writes = 0
	local context = {
		startStage = function() end,
		shouldStop = function() return false end,
		addError = function(_, err) error(err) end,
		advance = function() end,
		report = function() end,
		finish = function() end,
		dbBegin = function()
			t:eq(in_transaction, false)
			in_transaction = true
			begins = begins + 1
		end,
		dbCommit = function()
			t:eq(in_transaction, true)
			in_transaction = false
			commits = commits + 1
		end,
	}
	local processor = BatchProcessor(context, FunctionTimer(function() return 0 end), 10)
	local items = {}
	for i = 1, 21 do
		items[i] = i
	end

	processor:processPrepared(items, "hashing", function(item)
		t:eq(in_transaction, false)
		return item * 2
	end, function(result)
		t:eq(in_transaction, true)
		writes = writes + 1
		t:eq(result, writes * 2)
	end)

	t:eq(begins, 3)
	t:eq(commits, 3)
	t:eq(writes, 21)
end

return test
