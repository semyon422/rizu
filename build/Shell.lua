local class = require("class")
local IShell = require("build.IShell")

---@class build.Shell: build.IShell
local Shell = class(IShell)

function Shell:execute(cmd)
	local ok, status, code = os.execute(cmd)
	return ok, code
end

function Shell:popen(cmd)
	local p = io.popen(cmd .. " 2>/dev/null")
	if not p then return nil end
	local res = p:read("*a")
	p:close()
	return res
end

return Shell
