local class = require("class")
local Version = require("rizu.pkg.Version")

---@class rizu.Dependency
---@operator call: rizu.Dependency
local Dependency = class()

---@param name string
---@param op string
---@param ver rizu.Version
function Dependency:new(name, op, ver)
	self.name = name
	self.op = op
	self.ver = ver
end

---@param dep_str string
---@return rizu.Dependency?
function Dependency:parse(dep_str)
	local name, op, ver = dep_str:match("^(.-)([<=>]+)(.-)$")
	return Dependency(name, op, Version:parse(ver))
end

return Dependency
