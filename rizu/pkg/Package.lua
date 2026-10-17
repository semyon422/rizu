local class = require("class")
local Dependency = require("rizu.pkg.Dependency")
local Version = require("rizu.pkg.Version")

---@class rizu.Package
---@operator call: rizu.Package
---@field name string
---@field display_name string?
---@field creator string?
---@field desc string?
---@field version rizu.Version
---@field deps rizu.Dependency[]
---@field types {[string]: any}
local Package = class()

---@param v any
---@return string?
local function nil_or_tostring(v)
	if v == nil then return nil end
	return tostring(v)
end

---@param tbl table
function Package:new(tbl)
	self.name = tostring(assert(tbl.name, "missing package name"))
	self.display_name = nil_or_tostring(tbl.display_name)
	self.creator = nil_or_tostring(tbl.creator)
	self.desc = nil_or_tostring(tbl.desc)
	self.version = Version:parse(nil_or_tostring(tbl.version))
	self.types = type(tbl.types) == "table" and tbl.types or {}

	---@type rizu.Dependency[]
	local deps = {}
	self.deps = deps
	if tbl.deps then
		for i, dep_str in ipairs(tbl.deps --[=[@as string[]]=]) do
			deps[i] = Dependency:parse(dep_str)
		end
	end
end

---@return string
function Package:getDisplayName()
	return self.display_name or self.name
end

return Package
