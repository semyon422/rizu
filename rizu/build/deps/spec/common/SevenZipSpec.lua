local SevenZipSpec = {}

function SevenZipSpec.add(deps, spec)
	local s7 = deps.sevenzip
	local dest = "${downloads_dir}/" .. s7.archive
	local extract = "${deps_dir}/" .. s7.dir
	table.insert(spec.steps, {
		id = "sevenzip_sdk",
		kind = "archive",
		outputs = {
			extract .. "/C/Alloc.c",
			extract .. "/C/LzmaLib.c",
		},
		inputs = {dest},
		actions = {
			{type = "download", url = s7.url, dest = dest},
			{type = "extract", format = "tar.xz", archive = dest, dest = extract, strip_components = 0},
		},
	})
end

return SevenZipSpec
