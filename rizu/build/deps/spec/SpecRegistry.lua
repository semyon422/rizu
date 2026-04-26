---@class rizu.build.deps.spec.SpecRegistry
local SpecRegistry = {}

local builders = {
	linux = function(deps) return require("rizu.build.deps.spec.LinuxSpec").build(deps) end,
	windows = function(deps) return require("rizu.build.deps.spec.WindowsSpec").build(deps) end,
	macos = function(deps) return require("rizu.build.deps.spec.MacosSpec").build(deps) end,
}

---@param target rizu.build.Target
---@param deps table
---@return rizu.build.deps.Spec
function SpecRegistry.build(target, deps)
	local builder = builders[target]
	if not builder then
		error("No DSL spec builder for target: " .. tostring(target))
	end
	return builder(deps)
end

return SpecRegistry
