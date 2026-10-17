local Manifest = require("rizu.build.deps.Manifest")

---@class rizu.build.deps.spec.common.BassDepsSpec
local BassDepsSpec = {}

---@alias rizu.build.deps.BassDependency "bass"|"bassmix"|"bass_fx"

---@type rizu.build.deps.BassDependency[]
local BASS_DEPS = {"bass", "bassmix", "bass_fx"}
---@type {[rizu.build.deps.BassDependency]: {[rizu.build.Target]: string}}
local OUTPUT_NAME = {
	bass = {linux = "libbass.so", windows = "bass.dll", macos = "libbass.dylib"},
	bassmix = {linux = "libbassmix.so", windows = "bassmix.dll", macos = "libbassmix.dylib"},
	bass_fx = {linux = "libbass_fx.so", windows = "bass_fx.dll", macos = "libbass_fx.dylib"},
}

---@param dep_name rizu.build.deps.BassDependency
---@param target rizu.build.Target
---@param extract string
---@return string?
local function getSourcePath(dep_name, target, extract)
	local name = OUTPUT_NAME[dep_name] and OUTPUT_NAME[dep_name][target]
	if not name then
		return nil
	end
	if target == "windows" then
		return extract .. "/x64/" .. name
	end
	if target == "linux" then
		return extract .. "/libs/x86_64/" .. name
	end
	return extract .. "/" .. name
end

---@param target rizu.build.Target
---@param spec rizu.build.deps.Spec
function BassDepsSpec.add(target, spec)
	for _, dep_name in ipairs(BASS_DEPS) do
		local entries = Manifest[dep_name] --[[@as {[rizu.build.Target]: rizu.build.deps.ManifestEntry}]]
		local cfg = entries[target]
		if cfg then
			local archive = "${downloads_dir}/" .. cfg.archive
			local extract = ("${deps_dir}/%s_%s"):format(dep_name, target)
			local src = assert(getSourcePath(dep_name, target, extract))
			local out_name = OUTPUT_NAME[dep_name][target]
			---@type rizu.build.deps.Action[]
			local actions = {
				{type = "download", url = cfg.url, dest = archive},
				{type = "extract", format = "zip", archive = archive, dest = extract},
			}

			table.insert(actions, {type = "assert_file", path = src})
			table.insert(actions, {type = "copy_exact", src = src, dst = "${bin_dir}/" .. out_name, flags = "-f"})

			table.insert(spec.steps, {
				id = ("dep_%s"):format(dep_name),
				kind = "archive",
				outputs = {"${bin_dir}/" .. out_name},
				actions = actions,
			})
		end
	end
end

return BassDepsSpec
