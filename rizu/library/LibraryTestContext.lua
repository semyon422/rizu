local class = require("class")
local table_util = require("table_util")
local Library = require("rizu.library.Library")
local Worker = require("rizu.library.Worker")
local Database = require("rizu.library.Database")
local LinuxFilesystem = require("fs.LinuxFilesystem")
local FunctionTimer = require("time.FunctionTimer")

---@class rizu.library.LibraryTestContext
---@operator call: rizu.library.LibraryTestContext
local LibraryTestContext = class()

function LibraryTestContext:new()
	self.currentTime = 0

	self.fs = LinuxFilesystem()
	local timer = FunctionTimer(function()
		return self.currentTime
	end)

	self.lib = Library(self.fs, "/test", timer)
	self.lib:setSync(true)
	local fs = self.fs
	function self.lib:createAndLoadWorker(workingDirectory)
		local worker = Worker(self, fs, workingDirectory, timer)
		function worker.db:load()
			Database.load(self, ":memory:")
		end
		worker:load()
		return worker
	end

	self.lib:load(":memory:")

	---@type rizu.library.TaskStatus[]
	self.statusUpdates = {}
	self.lib.onStatusChanged:add({
		receive = function(_, status)
			-- Deep copy status to record history correctly
			table.insert(self.statusUpdates, table_util.deepcopy(status))
		end,
	})
end

function LibraryTestContext:process()
	self.lib:process()
end

---@param amount number
function LibraryTestContext:advanceTime(amount)
	self.currentTime = self.currentTime + amount
end

function LibraryTestContext:cleanup()
	self.lib:unload()
end

return LibraryTestContext
