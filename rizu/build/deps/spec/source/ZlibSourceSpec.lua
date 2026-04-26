local MacOSCross = require("rizu.build.deps.spec.source.MacOSCross")

local ZlibSourceSpec = {}

local macos_sources = {
	"adler32.c",
	"crc32.c",
	"deflate.c",
	"infback.c",
	"inffast.c",
	"inflate.c",
	"inftrees.c",
	"trees.c",
	"zutil.c",
	"compress.c",
	"uncompr.c",
	"gzclose.c",
	"gzlib.c",
	"gzread.c",
	"gzwrite.c",
}

---@param target rizu.build.Target
---@param spec rizu.build.deps.Spec
---@param deps table
---@param prefix string
---@param prefix_abs string
---@param tc_bin string?
function ZlibSourceSpec.add(target, spec, deps, prefix, prefix_abs, tc_bin)
	local zlib = deps.zlib_source and deps.zlib_source[target]
	if not zlib then
		return
	end
	local archive = "${downloads_dir}/" .. zlib.archive
	local extract = "${deps_dir}/" .. zlib.dir

	if target == "linux" then
		table.insert(spec.steps, {
			id = "linux_zlib",
			kind = "source-build",
			actions = {
				{type = "download", url = zlib.url, dest = archive},
				{type = "extract", format = "tar.gz", archive = archive, dest = extract},
				{type = "configure", dir = extract, args = {"--prefix=" .. prefix_abs}},
				{type = "make", dir = extract, args = {"-j$(nproc)"}},
				{type = "make", dir = extract, args = {"install"}},
				{type = "assert_file", path = prefix .. "/lib/libz.so.1"},
				{type = "copy_exact", src = prefix .. "/lib/libz.so.1", dst = "${bin_dir}/libz.so.1", flags = "-Lf"},
				{type = "remove", path = "${bin_dir}/libz.so"},
			},
		})
	elseif target == "windows" then
		table.insert(spec.steps, {
			id = "windows_zlib",
			kind = "source-build",
			actions = {
				{type = "download", url = zlib.url, dest = archive},
				{type = "extract", format = "tar.gz", archive = archive, dest = extract},
				{type = "make", dir = extract, args = {"-f", "win32/Makefile.gcc", "clean"}},
				{type = "make", dir = extract, args = {"-f", "win32/Makefile.gcc", "PREFIX=x86_64-w64-mingw32-", "SHARED_MODE=1", "BINARY_PATH=" .. prefix_abs .. "/bin", "INCLUDE_PATH=" .. prefix_abs .. "/include", "LIBRARY_PATH=" .. prefix_abs .. "/lib", "-j$(nproc)"}},
				{type = "ensure_dir", path = prefix .. "/bin"},
				{type = "copy_exact", src = extract .. "/zlib1.dll", dst = prefix .. "/bin/zlib1.dll", flags = "-f"},
				{type = "copy", src = prefix .. "/bin/zlib1.dll", dst = "${bin_dir}/z.dll", flags = "-f"},
			},
		})
	elseif target == "macos" then
		---@cast tc_bin string
		table.insert(spec.steps, {
			id = "macos_zlib",
			kind = "source-build",
			actions = {
				{type = "download", url = zlib.url, dest = archive},
				{type = "extract", format = "tar.gz", archive = archive, dest = extract},
				{
					type = "compile_c",
					compiler = MacOSCross.cc(tc_bin),
					dir = extract,
					env = MacOSCross.env(tc_bin),
					cflags = {"-dynamiclib", "-fPIC", "-O2", "-DHAVE_UNISTD_H", "-install_name", "@rpath/libz.dylib"},
					sources = macos_sources,
					output = prefix_abs .. "/lib/libz.dylib",
				},
				{type = "copy_exact", src = extract .. "/zlib.h", dst = prefix .. "/include/zlib.h", flags = "-f"},
				{type = "copy_exact", src = extract .. "/zconf.h", dst = prefix .. "/include/zconf.h", flags = "-f"},
				{type = "copy", src = prefix .. "/lib/libz.dylib", dst = "${bin_dir}/libz.dylib", flags = "-f"},
			},
		})
	end
end

return ZlibSourceSpec
