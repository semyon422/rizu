local class = require("class")
local table_util = require("table_util")
local Library = require("rizu.library.Library")
local LinuxFilesystem = require("fs.LinuxFilesystem")

---@class rizu.library.LibraryTestContext
---@operator call: rizu.library.LibraryTestContext
local LibraryTestContext = class()

function LibraryTestContext:new()
	self.currentTime = 0

	self.fs = LinuxFilesystem()

	self.lib = Library(self.fs, "/test", function() return self.currentTime end)
	self.lib:setSync(true)

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
