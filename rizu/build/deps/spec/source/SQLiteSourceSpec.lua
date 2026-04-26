local MacOSCross = require("rizu.build.deps.spec.source.MacOSCross")

local SQLiteSourceSpec = {}

---@param target rizu.build.Target
---@param spec rizu.build.deps.Spec
---@param deps table
---@param _prefix string
---@param _prefix_abs string
---@param tc_bin string?
function SQLiteSourceSpec.add(target, spec, deps, _prefix, _prefix_abs, tc_bin)
	local sqlite = deps.sqlite_source and deps.sqlite_source[target]
	if not sqlite then
		return
	end
	local archive = "${downloads_dir}/" .. sqlite.archive
	local extract = "${deps_dir}/" .. sqlite.dir

	if target == "linux" then
		table.insert(spec.steps, {
			id = "linux_sqlite",
			kind = "source-build",
			actions = {
				{type = "download", url = sqlite.url, dest = archive},
				{type = "extract", format = "tar.gz", archive = archive, dest = extract, skip_if_exists = true},
				{
					type = "compile_c",
					compiler = "gcc",
					cflags = {"-shared", "-fPIC", "-O2"},
					sources = {extract .. "/sqlite3.c"},
					output = "${bin_dir}/libsqlite3.so",
					libs = {"m", "dl", "pthread"},
				},
			},
		})
	elseif target == "windows" then
		table.insert(spec.steps, {
			id = "windows_sqlite",
			kind = "source-build",
			actions = {
				{type = "download", url = sqlite.url, dest = archive},
				{type = "extract", format = "tar.gz", archive = archive, dest = extract, skip_if_exists = true},
				{
					type = "compile_c",
					compiler = "x86_64-w64-mingw32-gcc",
					cflags = {"-shared", "-O2"},
					sources = {extract .. "/sqlite3.c"},
					output = "${bin_dir}/sqlite3.dll",
				},
			},
		})
	elseif target == "macos" then
		---@cast tc_bin string
		table.insert(spec.steps, {
			id = "macos_sqlite",
			kind = "source-build",
			actions = {
				{type = "download", url = sqlite.url, dest = archive},
				{type = "extract", format = "tar.gz", archive = archive, dest = extract, skip_if_exists = true},
				{
					type = "compile_c",
					compiler = MacOSCross.cc(tc_bin),
					env = MacOSCross.env(tc_bin),
					cflags = {"-dynamiclib", "-fPIC", "-O2", "-install_name", "@rpath/libsqlite3.dylib"},
					sources = {extract .. "/sqlite3.c"},
					output = "${bin_dir}/libsqlite3.dylib",
				},
			},
		})
	end
end

return SQLiteSourceSpec
