---@class rizu.build.deps.spec.SpecNormalizer
local SpecNormalizer = {}

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
function SpecNormalizer.normalize(spec)
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

return SpecNormalizer
