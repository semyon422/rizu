local BuildConfig = require("build.BuildConfig")

local Loader = {}

local builders = {
	linux = function(deps) return require("build.deps_dsl.spec.linux").build(deps) end,
	windows = function(deps) return require("build.deps_dsl.spec.windows").build(deps) end,
	macos = function(deps) return require("build.deps_dsl.spec.macos").build(deps) end,
}

local function validateAction(action)
	if type(action) ~= "table" then
		error("Action must be a table")
	end
	if not action.type then
		error("Action is missing required field 'type'")
	end
end

local function validateStep(step)
	if type(step) ~= "table" then
		error("Step must be a table")
	end
	if not step.id then
		error("Step is missing required field 'id'")
	end
	if not step.kind then
		error("Step '" .. tostring(step.id) .. "' is missing required field 'kind'")
	end
	if type(step.actions) ~= "table" then
		error("Step '" .. tostring(step.id) .. "' must define actions table")
	end
	for _, action in ipairs(step.actions) do
		validateAction(action)
	end
end

local function validateSpec(spec)
	if type(spec) ~= "table" then
		error("Spec must be a table")
	end
	if type(spec.steps) ~= "table" then
		error("Spec is missing steps table")
	end
	if type(spec.required_paths) ~= "table" then
		error("Spec is missing required_paths table")
	end
	if type(spec.status_rows) ~= "table" then
		error("Spec is missing status_rows table")
	end
	for _, step in ipairs(spec.steps) do
		validateStep(step)
	end
end

function Loader.load(target, deps)
	local t = BuildConfig.normalizeTarget(target)
	local builder = builders[t]
	if not builder then
		error("No DSL spec builder for target: " .. t)
	end
	local spec = builder(deps)
	spec.target = t
	validateSpec(spec)
	return spec
end

return Loader
