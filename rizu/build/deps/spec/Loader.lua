---@class rizu.build.deps.spec.Loader
local Loader = {}

local builders = {
	linux = function(deps) return require("rizu.build.deps.spec.LinuxSpec").build(deps) end,
	windows = function(deps) return require("rizu.build.deps.spec.WindowsSpec").build(deps) end,
	macos = function(deps) return require("rizu.build.deps.spec.MacosSpec").build(deps) end,
}

local step_kinds = {
	archive = true,
	git = true,
	["source-build"] = true,
}

local action_requirements = {
	download = {"url", "dest"},
	extract = {"format", "archive", "dest"},
	extract_first_match = {"pattern", "format", "dest"},
	configure = {"dir"},
	compile_c = {"compiler", "output", "sources"},
	compile_cpp = {"compiler", "output", "sources"},
	make = {"dir"},
	cmake_configure = {"src_dir", "build_dir"},
	cmake_build = {"build_dir"},
	copy = {"src", "dst"},
	copy_exact = {"src", "dst"},
	move_first_match = {"pattern", "dst"},
	remove = {"path"},
	set_executable = {"path"},
	write_file = {"path", "content"},
	git_clone = {"url", "dest"},
	git_submodule = {"dir"},
	shell = {"command"},
	ensure_dir = {"path"},
	assert_exists = {"path"},
	assert_file = {"path"},
	assert_dir = {"path"},
	noop = {},
}

---@param step rizu.build.deps.Step
---@return string[]
local function inferOutputsFromActions(step)
	local function normalizeOutput(action, path)
		if type(path) ~= "string" then
			return path
		end
		if not action or not action.dir then
			return path
		end
		if path:match("^/") or path:match("^[A-Za-z]:[/\\]") or path:match("^%${") then
			return path
		end
		return tostring(action.dir) .. "/" .. path
	end

	local outputs = {}
	for _, action in ipairs(step.actions or {}) do
		if action.type == "download" and action.dest then
			table.insert(outputs, action.dest)
		elseif action.type == "extract" and action.dest then
			table.insert(outputs, action.dest)
		elseif action.type == "copy" and action.dst and not tostring(action.dst):match("/$") then
			table.insert(outputs, action.dst)
		elseif action.type == "copy_exact" and action.dst and not tostring(action.dst):match("/$") then
			table.insert(outputs, action.dst)
		elseif action.type == "git_clone" and action.dest then
			table.insert(outputs, action.dest)
		elseif action.type == "git_submodule" and action.marker then
			table.insert(outputs, action.marker)
		elseif action.type == "set_executable" and action.path then
			table.insert(outputs, action.path)
		elseif action.type == "write_file" and action.path then
			table.insert(outputs, action.path)
		elseif (action.type == "compile_c" or action.type == "compile_cpp") and action.output then
			table.insert(outputs, normalizeOutput(action, action.output))
		end
	end
	return outputs
end

---@param spec rizu.build.deps.Spec
---@return rizu.build.deps.Spec
local function normalizeSpec(spec)
	spec.steps = spec.steps or {}
	for _, step in ipairs(spec.steps) do
		step.outputs = step.outputs or inferOutputsFromActions(step)
		step.requires = step.requires or {}
		step.inputs = step.inputs or {}
		step.status_label = step.status_label or step.id
	end
	spec.outputs = spec.outputs or {}
	if #spec.outputs == 0 then
		for _, step in ipairs(spec.steps) do
			for _, out in ipairs(step.outputs or {}) do
				table.insert(spec.outputs, out)
			end
		end
	end
	return spec
end

---@param action rizu.build.deps.Action
---@param step rizu.build.deps.Step
local function validateAction(action, step)
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
	if action.type == "shell" then
		local command = tostring(action.command or "")
		local fallback_patterns = {
			"%|%|%s*cp%s",
			"if%s*%[.-%];%s*then%s*cp%s.-%s*else%s*cp%s",
			"if%s*%[",
		}
		for _, pattern in ipairs(fallback_patterns) do
			if command:match(pattern) then
				error(string.format("Shell action '%s' contains forbidden fallback pattern '%s'", tostring(step.id), pattern))
			end
		end
	end
end

---@param step rizu.build.deps.Step
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
		validateAction(action, step)
	end
	if type(step.outputs) ~= "table" then
		error("Step '" .. tostring(step.id) .. "' must define outputs table")
	end
	if type(step.requires) ~= "table" then
		error("Step '" .. tostring(step.id) .. "' must define requires table")
	end
	if type(step.inputs) ~= "table" then
		error("Step '" .. tostring(step.id) .. "' must define inputs table")
	end
end

---@param spec rizu.build.deps.Spec
local function validateSpec(spec)
	if type(spec) ~= "table" then
		error("Spec must be a table")
	end
	if type(spec.steps) ~= "table" then
		error("Spec is missing steps table")
	end
	if type(spec.outputs) ~= "table" then
		error("Spec is missing outputs table")
	end
	---@type {[string]: true}
	local ids = {}
	for _, step in ipairs(spec.steps) do
		validateStep(step)
		if ids[step.id] then
			error("Duplicate step id in spec: " .. tostring(step.id))
		end
		ids[step.id] = true
	end
end

---@param target rizu.build.Target
---@param deps table
---@return rizu.build.deps.Spec
function Loader.load(target, deps)
	local builder = builders[target]
	if not builder then
		error("No DSL spec builder for target: " .. tostring(target))
	end
	local spec = normalizeSpec(builder(deps))
	spec.target = target
	validateSpec(spec)
	return spec
end

---@param spec rizu.build.deps.Spec
---@return boolean
function Loader.validate(spec)
	validateSpec(normalizeSpec(spec))
	return true
end

return Loader
