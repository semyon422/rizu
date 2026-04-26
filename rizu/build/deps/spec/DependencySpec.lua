local SpecNormalizer = require("rizu.build.deps.spec.SpecNormalizer")
local SpecRegistry = require("rizu.build.deps.spec.SpecRegistry")
local SpecValidator = require("rizu.build.deps.spec.SpecValidator")

---@class rizu.build.deps.spec.DependencySpec
local DependencySpec = {}

---@param target rizu.build.Target
---@param deps table
---@return rizu.build.deps.Spec
function DependencySpec.load(target, deps)
	local spec = SpecNormalizer.normalize(SpecRegistry.build(target, deps))
	spec.target = target
	SpecValidator.validate(spec)
	return spec
end

return DependencySpec
