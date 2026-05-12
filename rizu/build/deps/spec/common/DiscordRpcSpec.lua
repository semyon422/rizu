---@class rizu.build.deps.spec.common.DiscordRpcSpec
local DiscordRpcSpec = {}

---@param target rizu.build.Target
---@param deps rizu.build.deps.Manifest
---@param spec rizu.build.deps.Spec
function DiscordRpcSpec.add(target, deps, spec)
	local cfg = deps.discord_rpc and deps.discord_rpc[target]
	if not cfg then
		return
	end

	local archive = "${downloads_dir}/" .. cfg.archive
	local extract = "${deps_dir}/discord_rpc_" .. target
	local source_map = {
		linux = extract .. "/discord-rpc/linux-dynamic/lib/libdiscord-rpc.so",
		windows = extract .. "/discord-rpc/win64-dynamic/bin/discord-rpc.dll",
		macos = extract .. "/discord-rpc/osx-dynamic/lib/libdiscord-rpc.dylib",
	}
	local source = source_map[target]
	if not source then
		return
	end
	local output_name_map = {
		linux = "libdiscord-rpc.so",
		windows = "discord-rpc.dll",
		macos = "libdiscord-rpc.dylib",
	}
	local output = "${bin_dir}/" .. output_name_map[target]

	table.insert(spec.steps, {
		id = "dep_discord_rpc",
		kind = "archive",
		outputs = {output},
		actions = {
			{type = "download", url = cfg.url, dest = archive},
			{type = "extract", format = "zip", archive = archive, dest = extract},
			{type = "assert_file", path = source},
			{type = "copy_exact", src = source, dst = output, flags = "-f"},
		},
	})
end

return DiscordRpcSpec
