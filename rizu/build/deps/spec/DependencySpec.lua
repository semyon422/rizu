local LinuxSpec = require("rizu.build.deps.spec.LinuxSpec")
local MacosSpec = require("rizu.build.deps.spec.MacosSpec")
local SpecNormalizer = require("rizu.build.deps.spec.SpecNormalizer")
local SpecValidator = require("rizu.build.deps.spec.SpecValidator")
local WindowsSpec = require("rizu.build.deps.spec.WindowsSpec")

---@class rizu.build.deps.spec.DependencySpec
local DependencySpec = {}

local builders = {
	linux = LinuxSpec.build,
	windows = WindowsSpec.build,
	macos = MacosSpec.build,
}

---@param target rizu.build.Target
---@return rizu.build.deps.Spec
local function buildBaseSpec(target)
	local builder = builders[target]
	if not builder then
		error("No dependency spec builder for target: " .. tostring(target))
	end
	return builder()
end

---@param target rizu.build.Target
---@return rizu.build.deps.Spec
function DependencySpec.load(target)
	local spec = SpecNormalizer.normalize(buildBaseSpec(target))
	spec.target = target
	SpecValidator.validate(spec)
	return spec
end

return DependencySpec
