---@class rizu.build.deps.spec.ActionSchema
local ActionSchema = {}

local requirements = {
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
	replace_text = {"path", "replacements"},
	git_clone = {"url", "dest"},
	git_submodule = {"dir"},
	shell = {"command"},
	ensure_dir = {"path"},
	assert_exists = {"path"},
	assert_file = {"path"},
	assert_dir = {"path"},
	noop = {},
}

local shell_fallback_patterns = {
	"%|%|%s*cp%s",
	"if%s*%[.-%];%s*then%s*cp%s.-%s*else%s*cp%s",
	"if%s*%[",
}

---@param action rizu.build.deps.Action
local function validateStripComponents(action)
	if action.strip_components == nil then
		return
	end
	local value = action.strip_components
	if type(value) ~= "number" or value < 0 or value % 1 ~= 0 then
		error("Action '" .. tostring(action.type) .. "' field 'strip_components' must be a non-negative integer")
	end
end

---@param action rizu.build.deps.Action
local function validateReplacements(action)
	if action.type ~= "replace_text" then
		return
	end
	if type(action.replacements) ~= "table" or #action.replacements == 0 then
		error("Action 'replace_text' field 'replacements' must be a non-empty array")
	end
	for i, replacement in ipairs(action.replacements) do
		if type(replacement.old_text) ~= "string" then
			error(string.format("Action 'replace_text' replacement %d is missing string field 'old_text'", i))
		end
		if type(replacement.new_text) ~= "string" then
			error(string.format("Action 'replace_text' replacement %d is missing string field 'new_text'", i))
		end
		if replacement.count ~= nil and (type(replacement.count) ~= "number" or replacement.count < 1 or replacement.count % 1 ~= 0) then
			error(string.format("Action 'replace_text' replacement %d field 'count' must be a positive integer", i))
		end
	end
end

---@param action rizu.build.deps.Action
---@param step rizu.build.deps.Step
function ActionSchema.validate(action, step)
	if type(action) ~= "table" then
		error("Action must be a table")
	end
	if not action.type then
		error("Action is missing required field 'type'")
	end
	local req = requirements[action.type]
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
		for _, pattern in ipairs(shell_fallback_patterns) do
			if command:match(pattern) then
				error(string.format("Shell action '%s' contains forbidden fallback pattern '%s'", tostring(step.id), pattern))
			end
		end
	end
	if action.type == "extract" or action.type == "extract_first_match" then
		validateStripComponents(action)
	end
	validateReplacements(action)
end

return ActionSchema
