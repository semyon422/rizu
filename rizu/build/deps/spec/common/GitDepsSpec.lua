---@class rizu.build.deps.spec.common.GitDepsSpec
local GitDepsSpec = {}

---@param deps rizu.build.deps.Manifest
---@param spec rizu.build.deps.Spec
function GitDepsSpec.add(deps, spec)
	for _, dep_name in ipairs({"minacalc", "luamidi"}) do
		local cfg = deps[dep_name]
		local dep_dir = "${deps_dir}/" .. dep_name
		table.insert(spec.steps, {
			id = "git_" .. dep_name,
			kind = "git",
			actions = {
				{type = "git_clone", url = cfg.url, dest = dep_dir},
			},
		})
	end

	table.insert(spec.steps, {
		id = "git_luamidi_submodule",
		kind = "git",
		actions = {
			{type = "git_submodule", dir = "${deps_dir}/luamidi", marker = "${deps_dir}/luamidi/rtmidi/RtMidi.h"},
		},
	})
end

return GitDepsSpec
