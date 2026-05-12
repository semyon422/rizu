local Dd32Spec = require("rizu.build.deps.spec.common.Dd32Spec")
local MacOSCross = require("rizu.build.deps.spec.source.MacOSCross")
local table_util = require("aqua.table_util")
local Manifest = require("rizu.build.deps.Manifest")

local IconvSourceSpec = {}

---@param target rizu.build.Target
---@param spec rizu.build.deps.Spec
---@param prefix string
---@param prefix_abs string
---@param tc_bin string?
function IconvSourceSpec.add(target, spec, prefix, prefix_abs, tc_bin)
	local iconv = Manifest.iconv_source and Manifest.iconv_source[target]
	if not iconv then
		return
	end
	local archive = "${downloads_dir}/" .. iconv.archive
	local extract = "${deps_dir}/" .. iconv.dir
	local actions = {
		{type = "download", url = iconv.url, dest = archive},
		{type = "extract", format = "tar.gz", archive = archive, dest = extract},
	}
	Dd32Spec.addSetup(actions)

	if target == "linux" then
		table_util.append(actions, {
			{
				type = "configure",
				dir = extract,
				env = Dd32Spec.env(),
				args = {"--prefix=" .. prefix_abs, "--enable-shared", "--disable-static", "CFLAGS=-fPIC"},
			},
			{type = "make", dir = extract, args = {"-j$(nproc)"}},
			{type = "make", dir = extract, args = {"install"}},
			{type = "assert_file", path = prefix .. "/lib/libiconv.so"},
			{type = "assert_file", path = prefix .. "/lib/libcharset.so"},
			{type = "copy_exact", src = prefix .. "/lib/libiconv.so", dst = "${bin_dir}/libiconv.so", flags = "-Lf"},
			{type = "copy_exact", src = prefix .. "/lib/libcharset.so", dst = "${bin_dir}/libcharset.so", flags = "-Lf"},
		})
	elseif target == "windows" then
		table_util.append(actions, {
			{type = "configure", dir = extract, env = Dd32Spec.env(), args = {"--host=x86_64-w64-mingw32", "--prefix=" .. prefix_abs, "--enable-shared", "--disable-static", "CFLAGS=-O2"}},
			{type = "make", dir = extract, args = {"-j$(nproc)"}},
			{type = "make", dir = extract, args = {"install"}},
			{type = "assert_file", path = prefix .. "/bin/libiconv-2.dll"},
			{type = "copy_exact", src = prefix .. "/bin/libiconv-2.dll", dst = "${bin_dir}/libiconv-2.dll", flags = "-f"},
		})
	elseif target == "macos" then
		---@cast tc_bin string
		table_util.append(actions, {
			{
				type = "configure",
				dir = extract,
				env = MacOSCross.envWithDd(tc_bin),
				args = {
					"--host=" .. MacOSCross.DARWIN_TRIPLE,
					"--prefix=" .. prefix_abs,
					"--enable-shared",
					"--disable-static",
					"CFLAGS=-O2 -fPIC",
				},
			},
			{type = "make", dir = extract, env = MacOSCross.env(tc_bin), args = {"-j$(nproc)"}},
			{type = "make", dir = extract, env = MacOSCross.env(tc_bin), args = {"install"}},
			{type = "copy", src = prefix .. "/lib/libiconv.dylib", dst = "${bin_dir}/libiconv.dylib", flags = "-f"},
			{type = "copy", src = prefix .. "/lib/libcharset.dylib", dst = "${bin_dir}/libcharset.dylib", flags = "-f"},
		})
	end

	table.insert(spec.steps, {
		id = target .. "_iconv",
		kind = "source-build",
		actions = actions,
	})
end

return IconvSourceSpec
