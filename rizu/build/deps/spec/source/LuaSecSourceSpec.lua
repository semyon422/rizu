local MacOSCross = require("rizu.build.deps.spec.source.MacOSCross")

local LuaSecSourceSpec = {}

local unix_sources = {
	"src/options.c",
	"src/x509.c",
	"src/context.c",
	"src/ssl.c",
	"src/config.c",
	"src/ec.c",
	"src/luasocket/io.c",
	"src/luasocket/buffer.c",
	"src/luasocket/timeout.c",
	"src/luasocket/usocket.c",
}

local windows_sources = {
	"src/options.c",
	"src/x509.c",
	"src/context.c",
	"src/ssl.c",
	"src/config.c",
	"src/ec.c",
	"src/luasocket/io.c",
	"src/luasocket/buffer.c",
	"src/luasocket/timeout.c",
	"src/luasocket/wsocket.c",
}

---@param target rizu.build.Target
---@param spec rizu.build.deps.Spec
---@param deps rizu.build.deps.Manifest
---@param prefix string
---@param prefix_abs string
---@param tc_bin string?
function LuaSecSourceSpec.add(target, spec, deps, prefix, prefix_abs, tc_bin)
	local luasec = deps.luasec_source and deps.luasec_source[target]
	if not luasec then
		return
	end
	local archive = "${downloads_dir}/" .. luasec.archive
	local extract = "${deps_dir}/" .. luasec.dir

	if target == "linux" then
		table.insert(spec.steps, {
			id = "linux_luasec",
			kind = "source-build",
			actions = {
				{type = "assert_exists", path = "tree/include/luajit-2.1/lua.h"},
				{type = "download", url = luasec.url, dest = archive},
				{type = "extract", format = "tar.gz", archive = archive, dest = extract},
				{type = "assert_file", path = prefix .. "/lib64/libssl.so.3"},
				{
					type = "compile_c",
					compiler = "gcc",
					dir = extract,
					cflags = {"-O2", "-fPIC", "-shared", "-DWITH_LUASOCKET"},
					includes = {"${root_abs}/tree/include/luajit-2.1", prefix_abs .. "/include", "src", "src/luasocket"},
					sources = unix_sources,
					output = "src/ssl.so",
					lib_dirs = {prefix_abs .. "/lib64"},
					libs = {"ssl", "crypto"},
					ldflags = {"-Wl,-rpath,\\$ORIGIN"},
				},
				{type = "copy", src = extract .. "/src/ssl.so", dst = "${bin_dir}/ssl.so", flags = "-f"},
			},
		})
	elseif target == "windows" then
		table.insert(spec.steps, {
			id = "windows_luasec",
			kind = "source-build",
			actions = {
				{type = "assert_exists", path = "tree/include/luajit-2.1/lua.h"},
				{type = "assert_exists", path = "tree/lib/libluajit-5.1.dll.a"},
				{type = "download", url = luasec.url, dest = archive},
				{type = "extract", format = "tar.gz", archive = archive, dest = extract},
				{type = "assert_file", path = prefix .. "/lib64/libssl.dll.a"},
				{
					type = "compile_c",
					compiler = "x86_64-w64-mingw32-gcc",
					dir = extract,
					cflags = {"-O2", "-shared", "-DWIN32", "-DWITH_LUASOCKET"},
					includes = {"${root_abs}/tree/include/luajit-2.1", prefix_abs .. "/include", "src", "src/luasocket"},
					sources = windows_sources,
					output = "src/ssl.dll",
					lib_dirs = {prefix_abs .. "/lib64", "${root_abs}/tree/lib"},
					libs = {"ssl", "crypto", "ws2_32", "crypt32", "gdi32", ":libluajit-5.1.dll.a"},
				},
				{type = "copy", src = extract .. "/src/ssl.dll", dst = "${bin_dir}/ssl.dll", flags = "-f"},
			},
		})
	elseif target == "macos" then
		---@cast tc_bin string
		table.insert(spec.steps, {
			id = "macos_luasec",
			kind = "source-build",
			actions = {
				{type = "assert_exists", path = "tree/include/luajit-2.1/lua.h"},
				{type = "download", url = luasec.url, dest = archive},
				{type = "extract", format = "tar.gz", archive = archive, dest = extract},
				{type = "assert_file", path = prefix .. "/lib/libssl.dylib"},
				{
					type = "compile_c",
					compiler = MacOSCross.cc(tc_bin),
					dir = extract,
					env = MacOSCross.env(tc_bin),
					cflags = {"-O2", "-dynamiclib", "-undefined", "dynamic_lookup", "-DWITH_LUASOCKET"},
					includes = {"${root_abs}/tree/include/luajit-2.1", prefix_abs .. "/include", "src", "src/luasocket"},
					sources = unix_sources,
					output = "src/ssl.dylib",
					lib_dirs = {prefix_abs .. "/lib"},
					libs = {"ssl", "crypto"},
					ldflags = {"-Wl,-rpath,@loader_path"},
				},
				{type = "copy", src = extract .. "/src/ssl.dylib", dst = "${bin_dir}/ssl.dylib", flags = "-f"},
			},
		})
	end
end

return LuaSecSourceSpec
