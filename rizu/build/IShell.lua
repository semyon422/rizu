local class = require("class")

---@class rizu.build.IShell
---@operator call: rizu.build.IShell
local IShell = class()

---@param cmd string
---@return boolean success
---@return number? code
function IShell:execute(cmd)
	error("not implemented")
end

---@param cmd string
---@return string? output
function IShell:popen(cmd)
	error("not implemented")
end

return IShell
