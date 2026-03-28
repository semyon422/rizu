local M = {}

function M.add(deps, spec)
	local s7 = deps.sevenzip
	local dest = "${downloads_dir}/" .. s7.archive
	local extract = "${deps_dir}/" .. s7.dir
	table.insert(spec.steps, {
		id = "sevenzip_sdk",
		kind = "archive",
		actions = {
			{type = "download", url = s7.url, dest = dest},
			{type = "extract", format = "7z", archive = dest, dest = extract},
		},
	})
end

return M
