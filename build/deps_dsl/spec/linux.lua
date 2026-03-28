local Common = require("build.deps_dsl.spec.common")

local Linux = {}

local function add_prepare_prefix(spec, prefix)
	table.insert(spec.steps, {
		id = "linux_prepare_prefix",
		kind = "source-build",
		actions = {
			{type = "ensure_dir", path = "${deps_dir}/local"},
			{type = "ensure_dir", path = prefix},
		},
	})
end

local function add_zlib(spec, deps, prefix, prefix_abs)
	local zlib = deps.zlib_source and deps.zlib_source.linux
	if not zlib then
		return
	end
	local archive = "${downloads_dir}/" .. zlib.archive
	local extract = "${deps_dir}/" .. zlib.dir
	table.insert(spec.steps, {
		id = "linux_zlib",
		kind = "source-build",
		actions = {
			{type = "download", url = zlib.url, dest = archive},
			{type = "extract", format = "tar.gz", archive = archive, dest = extract, skip_if_exists = true},
			{type = "shell", dir = extract, stderr_hint = "Shell command failed", command = "./configure --prefix=" .. prefix_abs .. " && make -j$(nproc) && make install"},
			{type = "assert_file", path = prefix .. "/lib/libz.so.1", message = "Expected zlib at " .. prefix .. "/lib/libz.so.1"},
			{type = "copy_exact", src = prefix .. "/lib/libz.so.1", dst = "${bin_dir}/libz.so.1", flags = "-Lf"},
			{type = "remove", path = "${bin_dir}/libz.so"},
		},
	})
end

local function add_iconv(spec, deps, prefix, prefix_abs)
	local iconv = deps.iconv_source and deps.iconv_source.linux
	if not iconv then
		return
	end
	local archive = "${downloads_dir}/" .. iconv.archive
	local extract = "${deps_dir}/" .. iconv.dir
	table.insert(spec.steps, {
		id = "linux_iconv",
		kind = "source-build",
		actions = {
			{type = "download", url = iconv.url, dest = archive},
			{type = "extract", format = "tar.gz", archive = archive, dest = extract, skip_if_exists = true},
			{type = "shell", dir = extract, stderr_hint = "Shell command failed", command = "./configure --prefix=" .. prefix_abs .. " --enable-shared --disable-static CFLAGS=\\\"-fPIC\\\" && make -j$(nproc) && make install"},
			{type = "assert_file", path = prefix .. "/lib/libiconv.so"},
			{type = "assert_file", path = prefix .. "/lib/libcharset.so"},
			{type = "copy_exact", src = prefix .. "/lib/libiconv.so", dst = "${bin_dir}/libiconv.so", flags = "-Lf"},
			{type = "copy_exact", src = prefix .. "/lib/libcharset.so", dst = "${bin_dir}/libcharset.so", flags = "-Lf"},
		},
	})
end

local function add_openssl(spec, deps, prefix, prefix_abs)
	local openssl = deps.openssl_source and deps.openssl_source.linux
	if not openssl then
		return
	end
	local archive = "${downloads_dir}/" .. openssl.archive
	local extract = "${deps_dir}/" .. openssl.dir
	table.insert(spec.steps, {
		id = "linux_openssl",
		kind = "source-build",
		actions = {
			{type = "download", url = openssl.url, dest = archive},
			{type = "extract", format = "tar.gz", archive = archive, dest = extract, skip_if_exists = true},
			{type = "shell", dir = extract, stderr_hint = "OpenSSL configure/build failed", command = "./Configure linux-x86_64 --prefix=" .. prefix_abs .. " --openssldir=" .. prefix_abs .. "/ssl shared zlib --with-zlib-include=" .. prefix_abs .. "/include --with-zlib-lib=" .. prefix_abs .. "/lib && make -j$(nproc) && make install_sw"},
			{type = "assert_file", path = prefix .. "/lib/libssl.so.3", message = "Expected OpenSSL at " .. prefix .. "/lib/libssl.so.3"},
			{type = "assert_file", path = prefix .. "/lib/libcrypto.so.3", message = "Expected OpenSSL at " .. prefix .. "/lib/libcrypto.so.3"},
			{type = "copy_exact", src = prefix .. "/lib/libssl.so.3", dst = "${bin_dir}/libssl.so.3", flags = "-Lf"},
			{type = "copy_exact", src = prefix .. "/lib/libcrypto.so.3", dst = "${bin_dir}/libcrypto.so.3", flags = "-Lf"},
			{type = "remove", path = "${bin_dir}/libssl.so"},
			{type = "remove", path = "${bin_dir}/libcrypto.so"},
		},
	})
end

local function add_luasec(spec, deps, prefix, prefix_abs)
	local luasec = deps.luasec_source and deps.luasec_source.linux
	if not luasec then
		return
	end
	local archive = "${downloads_dir}/" .. luasec.archive
	local extract = "${deps_dir}/" .. luasec.dir
	table.insert(spec.steps, {
		id = "linux_luasec",
		kind = "source-build",
		actions = {
			{type = "assert_exists", path = "tree/include/luajit-2.1/lua.h", message = "LuaJIT headers are missing at tree/include/luajit-2.1. Run ./build/make.lua luajit linux first."},
			{type = "download", url = luasec.url, dest = archive},
			{type = "extract", format = "tar.gz", archive = archive, dest = extract, skip_if_exists = true},
			{type = "assert_file", path = prefix .. "/lib/libssl.so.3", message = "Expected OpenSSL at " .. prefix .. "/lib/libssl.so.3"},
			{type = "run_in_dir", dir = extract, command = "gcc -O2 -fPIC -shared -DWITH_LUASOCKET -I${root_abs}/tree/include/luajit-2.1 -I" .. prefix_abs .. "/include -Isrc -Isrc/luasocket src/options.c src/x509.c src/context.c src/ssl.c src/config.c src/ec.c src/luasocket/io.c src/luasocket/buffer.c src/luasocket/timeout.c src/luasocket/usocket.c -o src/ssl.so -L" .. prefix_abs .. "/lib -Wl,-rpath,\\$ORIGIN -lssl -lcrypto", stderr_hint = "luasec linux build failed"},
			{type = "copy", src = extract .. "/src/ssl.so", dst = "${bin_dir}/ssl.so", flags = "-f"},
		},
	})
end

local function add_sqlite(spec, deps)
	local sqlite = deps.sqlite_source and deps.sqlite_source.linux
	if not sqlite then
		return
	end
	local archive = "${downloads_dir}/" .. sqlite.archive
	local extract = "${deps_dir}/" .. sqlite.dir
	table.insert(spec.steps, {
		id = "linux_sqlite",
		kind = "source-build",
		actions = {
			{type = "download", url = sqlite.url, dest = archive},
			{type = "extract", format = "tar.gz", archive = archive, dest = extract, skip_if_exists = true},
			{type = "shell", stderr_hint = "Shell command failed", command = "gcc -shared -fPIC -O2 " .. extract .. "/sqlite3.c -o ${bin_dir}/libsqlite3.so -lm -ldl -lpthread"},
		},
	})
end

local function add_fftw(spec, deps)
	local fftw = deps.fftw_source and deps.fftw_source.linux
	if not fftw then
		return
	end
	local archive = "${downloads_dir}/" .. fftw.archive
	local extract = "${deps_dir}/" .. fftw.dir
	table.insert(spec.steps, {
		id = "linux_fftw",
		kind = "source-build",
		actions = {
			{type = "download", url = fftw.url, dest = archive},
			{type = "extract", format = "tar.gz", archive = archive, dest = extract, skip_if_exists = true},
			{type = "shell", stderr_hint = "Shell command failed", command = "cmake -S " .. extract .. " -B " .. extract .. "/build-cmake -DBUILD_SHARED_LIBS=ON && cmake --build " .. extract .. "/build-cmake -j$(nproc)"},
			{type = "assert_file", path = extract .. "/build-cmake/libfftw3.so"},
			{type = "copy_exact", src = extract .. "/build-cmake/libfftw3.so", dst = "${bin_dir}/libfftw3.so", flags = "-L"},
		},
	})
end

function Linux.build(deps)
	local spec = Common.buildShared("linux", deps)
	local prefix = "${deps_dir}/local/linux"
	local prefix_abs = "${root_abs}/build/deps/local/linux"

	add_prepare_prefix(spec, prefix)
	add_zlib(spec, deps, prefix, prefix_abs)
	add_iconv(spec, deps, prefix, prefix_abs)
	add_openssl(spec, deps, prefix, prefix_abs)
	add_luasec(spec, deps, prefix, prefix_abs)
	add_sqlite(spec, deps)
	add_fftw(spec, deps)

	return spec
end

return Linux
