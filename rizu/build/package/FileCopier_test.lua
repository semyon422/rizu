local FakeFilesystem = require("fs.FakeFilesystem")
local Context = require("rizu.build.Context")
local Shell = require("rizu.build.Shell")
local FileCopier = require("rizu.build.package.FileCopier")

local test = {}

---@param t testing.T
function test.copy_failure_aborts_before_chmod(t)
	local fs = FakeFilesystem()
	local ctx = Context(fs, Shell(), {})
	t:has_error(function()
		FileCopier.copy(ctx, "missing", "destination")
	end)
	t:eq(fs:getInfo("destination"), nil)
end

---@param t testing.T
function test.permission_failure_aborts_packaging(t)
	local fs = FakeFilesystem()
	fs:write("source", "payload")
	local shell = Shell()
	local called = false
	function shell:execute(_cmd)
		called = true
		error("permission copy failed")
	end
	local ctx = Context(fs, shell, {})
	t:has_error(function()
		FileCopier.copy(ctx, "source", "destination")
	end)
	t:assert(called)
	t:eq(fs:read("destination"), "payload")
end

return test
