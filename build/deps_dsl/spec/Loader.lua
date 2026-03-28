local BuildConfig = require("build.BuildConfig")

local Loader = {}

local builders = {
	linux = function(deps) return require("build.deps_dsl.spec.linux").build(deps) end,
	windows = function(deps) return require("build.deps_dsl.spec.windows").build(deps) end,
	macos = function(deps) return require("build.deps_dsl.spec.macos").build(deps) end,
}

local step_kinds = {
	archive = true,
	git = true,
	["source-build"] = true,
}

local action_requirements = {
	download = {"url", "dest"},
	extract = {"format", "archive", "dest"},
	configure = {"dir", "command"},
	make = {"dir"},
	copy = {"src", "dst"},
	remove = {"path"},
	git_clone = {"url", "dest"},
	git_submodule = {"dir"},
	install_name_tool_change = {"tool", "target"},
	shell = {"command"},
	ensure_dir = {"path"},
	assert_exists = {"path"},
}

local status_requirements = {
	dl_ex = {"name", "download", "extract"},
	exists = {"name", "path"},
	exists_all = {"name", "paths"},
}

local function validateAction(action)
	if type(action) ~= "table" then
		error("Action must be a table")
	end
	if not action.type then
		error("Action is missing required field 'type'")
	end
	local req = action_requirements[action.type]
	if not req then
		error("Unknown action type in schema: " .. tostring(action.type))
	end
	for _, key in ipairs(req) do
		if action[key] == nil then
			error(string.format("Action '%s' is missing required field '%s'", action.type, key))
		end
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
	if not step_kinds[step.kind] then
		error("Step '" .. tostring(step.id) .. "' has unsupported kind '" .. tostring(step.kind) .. "'")
	end
	if type(step.actions) ~= "table" then
		error("Step '" .. tostring(step.id) .. "' must define actions table")
	end
	for _, action in ipairs(step.actions) do
		validateAction(action)
	end
end

local function validateStatusRows(spec)
	for _, row in ipairs(spec.status_rows) do
		if type(row) ~= "table" then
			error("Status row must be a table")
		end
		local req = status_requirements[row.format]
		if not req then
			error("Unknown status format in schema: " .. tostring(row.format))
		end
		for _, key in ipairs(req) do
			if row[key] == nil then
				error(string.format("Status row '%s' missing required field '%s'", tostring(row.name), key))
			end
		end
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
	local ids = {}
	for _, step in ipairs(spec.steps) do
		validateStep(step)
		if ids[step.id] then
			error("Duplicate step id in spec: " .. tostring(step.id))
		end
		ids[step.id] = true
	end
	validateStatusRows(spec)
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

function Loader.validate(spec)
	validateSpec(spec)
	return true
end

return Loader
