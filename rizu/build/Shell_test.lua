local Shell = require("rizu.build.Shell")

local test = {}

---@param t testing.T
function test.execute_reports_unencoded_exit_code(t)
	local shell = Shell()
	local ok, err = pcall(function()
		shell:execute("sh -c 'exit 22'")
	end)

	t:eq(ok, false)
	t:assert(tostring(err):find("exit 22", 1, true) ~= nil, tostring(err))
end

return test
