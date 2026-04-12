local Common = require("rizu.build.deps.spec.CommonSpec")

local Windows = {}

local DD32_PATH = "${root_abs}/${deps_dir}/dd32.sh"

local function add_dd32(actions)
	table.insert(actions, {type = "write_file", path = "${deps_dir}/dd32.sh", content = "#!/bin/sh\ncat | head -c 32\n"})
	table.insert(actions, {type = "set_executable", path = "${deps_dir}/dd32.sh"})
end

local function get_dd32_env()
	return {
		ac_cv_path_lt_DD = DD32_PATH,
		DD = DD32_PATH,
	}
end

local function add_prepare_prefix(spec, prefix)
	table.insert(spec.steps, {
		id = "windows_prepare_prefix",
		kind = "source-build",
		actions = {
			{type = "ensure_dir", path = "${deps_dir}/local"},
			{type = "ensure_dir", path = prefix},
		},
	})
end

local function add_zlib(spec, deps, prefix, prefix_abs)
	local zlib = deps.zlib_source and deps.zlib_source.windows
	if not zlib then
		return
	end
	local archive = "${downloads_dir}/" .. zlib.archive
	local extract = "${deps_dir}/" .. zlib.dir
	table.insert(spec.steps, {
		id = "windows_zlib",
		kind = "source-build",
		actions = {
			{type = "download", url = zlib.url, dest = archive},
			{type = "extract", format = "tar.gz", archive = archive, dest = extract, skip_if_exists = true},
			{type = "make", dir = extract, args = {"-f", "win32/Makefile.gcc", "clean"}},
			{type = "make", dir = extract, args = {"-f", "win32/Makefile.gcc", "PREFIX=x86_64-w64-mingw32-", "SHARED_MODE=1", "BINARY_PATH=" .. prefix_abs .. "/bin", "INCLUDE_PATH=" .. prefix_abs .. "/include", "LIBRARY_PATH=" .. prefix_abs .. "/lib", "-j$(nproc)"}},
			{type = "ensure_dir", path = prefix .. "/bin"},
			{type = "copy_exact", src = extract .. "/zlib1.dll", dst = prefix .. "/bin/zlib1.dll", flags = "-f"},
			{type = "copy", src = prefix .. "/bin/zlib1.dll", dst = "${bin_dir}/z.dll", flags = "-f"},
		},
	})
end

local function add_iconv(spec, deps, prefix, prefix_abs)
	local iconv = deps.iconv_source and deps.iconv_source.windows
	if not iconv then
		return
	end
	local archive = "${downloads_dir}/" .. iconv.archive
	local extract = "${deps_dir}/" .. iconv.dir
	local actions = {
		{type = "download", url = iconv.url, dest = archive},
		{type = "extract", format = "tar.gz", archive = archive, dest = extract, skip_if_exists = true},
	}
	add_dd32(actions)
	table.insert(actions, {type = "configure", dir = extract, env = get_dd32_env(), args = {"--host=x86_64-w64-mingw32", "--prefix=" .. prefix_abs, "--enable-shared", "--disable-static", "CFLAGS=-O2"}})
	table.insert(actions, {type = "make", dir = extract, args = {"-j$(nproc)"}})
	table.insert(actions, {type = "make", dir = extract, args = {"install"}})
	table.insert(actions, {type = "assert_file", path = prefix .. "/bin/libiconv-2.dll"})
	table.insert(actions, {type = "copy_exact", src = prefix .. "/bin/libiconv-2.dll", dst = "${bin_dir}/libiconv-2.dll", flags = "-f"})
	table.insert(spec.steps, {
		id = "windows_iconv",
		kind = "source-build",
		actions = actions,
	})
end

local function add_openssl(spec, deps, prefix, prefix_abs)
	local openssl = deps.openssl_source and deps.openssl_source.windows
	if not openssl then
		return
	end
	local archive = "${downloads_dir}/" .. openssl.archive
	local extract = "${deps_dir}/" .. openssl.dir
	table.insert(spec.steps, {
		id = "windows_openssl",
		kind = "source-build",
		actions = {
			{type = "download", url = openssl.url, dest = archive},
			{type = "extract", format = "tar.gz", archive = archive, dest = extract, skip_if_exists = true},
			{type = "configure", dir = extract, script = "./Configure", args = {"mingw64", "shared", "--cross-compile-prefix=x86_64-w64-mingw32-", "--prefix=" .. prefix_abs, "--openssldir=" .. prefix_abs .. "/ssl"}},
			{type = "make", dir = extract, args = {"-j$(nproc)"}},
			{type = "make", dir = extract, args = {"install_sw"}},
			{type = "assert_file", path = prefix .. "/bin/libssl-3-x64.dll"},
			{type = "assert_file", path = prefix .. "/bin/libcrypto-3-x64.dll"},
			{type = "copy_exact", src = prefix .. "/bin/libssl-3-x64.dll", dst = "${bin_dir}/libssl-3-x64.dll", flags = "-f"},
			{type = "copy_exact", src = prefix .. "/bin/libcrypto-3-x64.dll", dst = "${bin_dir}/libcrypto-3-x64.dll", flags = "-f"},
		},
	})
end

local function add_luasec(spec, deps, prefix, prefix_abs)
	local luasec = deps.luasec_source and deps.luasec_source.windows
	if not luasec then
		return
	end
	local archive = "${downloads_dir}/" .. luasec.archive
	local extract = "${deps_dir}/" .. luasec.dir
	table.insert(spec.steps, {
		id = "windows_luasec",
		kind = "source-build",
		actions = {
			{type = "assert_exists", path = "tree/include/luajit-2.1/lua.h"},
			{type = "assert_exists", path = "tree/lib/libluajit-5.1.dll.a"},
			{type = "download", url = luasec.url, dest = archive},
			{type = "extract", format = "tar.gz", archive = archive, dest = extract, skip_if_exists = true},
			{type = "assert_file", path = prefix .. "/lib64/libssl.dll.a"},
			{
				type = "compile_c",
				compiler = "x86_64-w64-mingw32-gcc",
				dir = extract,
				cflags = {"-O2", "-shared", "-DWIN32", "-DWITH_LUASOCKET"},
				includes = {"${root_abs}/tree/include/luajit-2.1", prefix_abs .. "/include", "src", "src/luasocket"},
				sources = {
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
				},
				output = "src/ssl.dll",
				lib_dirs = {prefix_abs .. "/lib64", "${root_abs}/tree/lib"},
				libs = {"ssl", "crypto", "ws2_32", "crypt32", "gdi32", ":libluajit-5.1.dll.a"},
			},
			{type = "copy", src = extract .. "/src/ssl.dll", dst = "${bin_dir}/ssl.dll", flags = "-f"},
		},
	})
end

local function add_fftw(spec, deps, prefix, prefix_abs)
	local fftw = deps.fftw_source and deps.fftw_source.windows
	if not fftw then
		return
	end
	local archive = "${downloads_dir}/" .. fftw.archive
	local extract = "${deps_dir}/" .. fftw.dir
	local actions = {
		{type = "download", url = fftw.url, dest = archive},
		{type = "extract", format = "tar.gz", archive = archive, dest = extract, skip_if_exists = true},
	}
	add_dd32(actions)
	table.insert(actions, {
		type = "configure",
		dir = extract,
		env = get_dd32_env(),
		args = {"--host=x86_64-w64-mingw32", "--prefix=" .. prefix_abs, "--enable-shared", "--disable-static", "CFLAGS=-O2"},
	})
	table.insert(actions, {type = "make", dir = extract, args = {"-j$(nproc)"}})
	table.insert(actions, {type = "make", dir = extract, args = {"install"}})
	table.insert(actions, {type = "assert_file", path = prefix .. "/bin/libfftw3-3.dll"})
	table.insert(actions, {type = "copy_exact", src = prefix .. "/bin/libfftw3-3.dll", dst = "${bin_dir}/libfftw3-3.dll", flags = "-f"})
	table.insert(spec.steps, {
		id = "windows_fftw",
		kind = "source-build",
		actions = actions,
	})
end

local function add_sqlite(spec, deps)
	local sqlite = deps.sqlite_source and deps.sqlite_source.windows
	if not sqlite then
		return
	end
	local archive = "${downloads_dir}/" .. sqlite.archive
	local extract = "${deps_dir}/" .. sqlite.dir
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
end

function Windows.build(deps)
	local spec = Common.buildShared("windows", deps)
	local prefix = "${deps_dir}/local/windows"
	local prefix_abs = "${root_abs}/build/deps/local/windows"

	add_prepare_prefix(spec, prefix)
	add_zlib(spec, deps, prefix, prefix_abs)
	add_iconv(spec, deps, prefix, prefix_abs)
	add_openssl(spec, deps, prefix, prefix_abs)
	add_luasec(spec, deps, prefix, prefix_abs)
	add_fftw(spec, deps, prefix, prefix_abs)
	add_sqlite(spec, deps)

	return spec
end

return Windows
