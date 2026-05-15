local class = require("class")
local IShell = require("rizu.build.IShell")

---@class rizu.build.Shell: rizu.build.IShell
---@operator call: rizu.build.Shell
local Shell = class(IShell)

local function normalize_status(ok, status, code)
	if type(ok) == "number" then
		if ok == 0 then
			return true, 0
		end
		if ok > 255 then
			return false, math.floor(ok / 256)
		end
		return false, ok
	end
	if ok == true then
		return true, 0
	end
	if ok == false then
		return false, code or status or 1
	end
	return false, code or status or 1
end

---@param cmd string
---@return boolean
---@return number?
function Shell:execute(cmd)
	local ok, status, code = os.execute(cmd)
	local success, exit_code = normalize_status(ok, status, code)
	if not success then
		error(string.format("Command failed (exit %s): %s", tostring(exit_code), cmd), 2)
	end
	return true, exit_code
end

---@param cmd string
---@return string?
function Shell:popen(cmd)
	local p = io.popen(cmd .. " 2>/dev/null")
	if not p then return nil end
	local res = p:read("*a")
	p:close()
	return res
end

return Shell
