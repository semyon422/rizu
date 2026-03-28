local Common = require("build.deps_dsl.spec.common")
local Templates = require("build.deps_dsl.spec.Templates")

local Linux = {}

function Linux.build(deps)
	local spec = Common.buildShared("linux", deps)

	local prefix = "${deps_dir}/local/linux"
	local prefix_abs = "${root_abs}/build/deps/local/linux"

	table.insert(spec.steps, {
		id = "linux_prepare_prefix",
		kind = "source-build",
		actions = {
			{type = "ensure_dir", path = "${deps_dir}/local"},
			{type = "ensure_dir", path = prefix},
		},
	})

	local zlib = deps.zlib_source and deps.zlib_source.linux
	if zlib then
		local archive = "${downloads_dir}/" .. zlib.archive
		local extract = "${deps_dir}/" .. zlib.dir
		table.insert(spec.steps, {
			id = "linux_zlib",
			kind = "source-build",
			actions = {
				{type = "download", url = zlib.url, dest = archive},
				{type = "extract", format = "tar.gz", archive = archive, dest = extract, skip_if_exists = true},
				{type = "shell", command = Templates.ifMissing(prefix .. "/lib/libz.so", Templates.bashInDir(extract, "./configure --prefix=" .. prefix_abs .. " && make -j$(nproc) && make install"))},
				{type = "shell", command = "if [ -f " .. prefix .. "/lib/libz.so.1 ]; then cp -Lf " .. prefix .. "/lib/libz.so.1 ${bin_dir}/libz.so.1; else cp -Lf " .. prefix .. "/lib/libz.so ${bin_dir}/libz.so.1; fi"},
				{type = "remove", path = "${bin_dir}/libz.so"},
			},
		})
		table.insert(spec.required_paths, extract)
		table.insert(spec.required_paths, "${bin_dir}/libz.so.1")
		table.insert(spec.status_rows, {name = "ZLIB (linux-src)", format = "dl_ex", download = archive, extract = extract})
		table.insert(spec.status_rows, {name = "ZLIB lib (linux)", format = "exists", path = "${bin_dir}/libz.so.1"})
	end

	local iconv = deps.iconv_source and deps.iconv_source.linux
	if iconv then
		local archive = "${downloads_dir}/" .. iconv.archive
		local extract = "${deps_dir}/" .. iconv.dir
		table.insert(spec.steps, {
			id = "linux_iconv",
			kind = "source-build",
			actions = {
				{type = "download", url = iconv.url, dest = archive},
				{type = "extract", format = "tar.gz", archive = archive, dest = extract, skip_if_exists = true},
				{type = "shell", command = Templates.ifAnyMissing({prefix .. "/lib/libiconv.so", prefix .. "/lib/libcharset.so"}, Templates.bashInDir(extract, "./configure --prefix=" .. prefix_abs .. " --enable-shared --disable-static CFLAGS=\\\"-fPIC\\\" && make -j$(nproc) && make install"))},
				{type = "shell", command = "cp -Lf " .. prefix .. "/lib/libiconv.so ${bin_dir}/libiconv.so"},
				{type = "shell", command = "cp -Lf " .. prefix .. "/lib/libcharset.so ${bin_dir}/libcharset.so"},
			},
		})
		table.insert(spec.required_paths, extract)
		table.insert(spec.required_paths, "${bin_dir}/libiconv.so")
		table.insert(spec.required_paths, "${bin_dir}/libcharset.so")
		table.insert(spec.status_rows, {name = "ICONV (linux-src)", format = "dl_ex", download = archive, extract = extract})
		table.insert(spec.status_rows, {name = "ICONV libs (linux)", format = "exists_all", paths = {"${bin_dir}/libiconv.so", "${bin_dir}/libcharset.so"}})
	end

	local openssl = deps.openssl_source and deps.openssl_source.linux
	if openssl then
		local archive = "${downloads_dir}/" .. openssl.archive
		local extract = "${deps_dir}/" .. openssl.dir
		table.insert(spec.steps, {
			id = "linux_openssl",
			kind = "source-build",
			actions = {
				{type = "download", url = openssl.url, dest = archive},
				{type = "extract", format = "tar.gz", archive = archive, dest = extract, skip_if_exists = true},
				{type = "shell", command = "if [ ! -f " .. prefix .. "/lib/libssl.so ] && [ ! -f " .. prefix .. "/lib64/libssl.so ]; then " .. Templates.bashInDir(extract, "./Configure linux-x86_64 --prefix=" .. prefix_abs .. " --openssldir=" .. prefix_abs .. "/ssl shared zlib --with-zlib-include=" .. prefix_abs .. "/include --with-zlib-lib=" .. prefix_abs .. "/lib && make -j$(nproc) && make install_sw") .. "; fi"},
				{type = "shell", command = "OPENSSL_LIB=\"" .. prefix .. "/lib\"; [ -f " .. prefix .. "/lib/libssl.so ] || OPENSSL_LIB=\"" .. prefix .. "/lib64\"; if [ -f $OPENSSL_LIB/libssl.so.3 ]; then cp -Lf $OPENSSL_LIB/libssl.so.3 ${bin_dir}/libssl.so.3; else cp -Lf $OPENSSL_LIB/libssl.so ${bin_dir}/libssl.so.3; fi"},
				{type = "shell", command = "OPENSSL_LIB=\"" .. prefix .. "/lib\"; [ -f " .. prefix .. "/lib/libcrypto.so ] || OPENSSL_LIB=\"" .. prefix .. "/lib64\"; if [ -f $OPENSSL_LIB/libcrypto.so.3 ]; then cp -Lf $OPENSSL_LIB/libcrypto.so.3 ${bin_dir}/libcrypto.so.3; else cp -Lf $OPENSSL_LIB/libcrypto.so ${bin_dir}/libcrypto.so.3; fi"},
				{type = "remove", path = "${bin_dir}/libssl.so"},
				{type = "remove", path = "${bin_dir}/libcrypto.so"},
			},
		})
		table.insert(spec.required_paths, extract)
		table.insert(spec.required_paths, "${bin_dir}/libssl.so.3")
		table.insert(spec.required_paths, "${bin_dir}/libcrypto.so.3")
		table.insert(spec.status_rows, {name = "OPENSSL (linux-src)", format = "dl_ex", download = archive, extract = extract})
		table.insert(spec.status_rows, {name = "OPENSSL libs (linux)", format = "exists_all", paths = {"${bin_dir}/libssl.so.3", "${bin_dir}/libcrypto.so.3"}})
	end

	local luasec = deps.luasec_source and deps.luasec_source.linux
	if luasec then
		local archive = "${downloads_dir}/" .. luasec.archive
		local extract = "${deps_dir}/" .. luasec.dir
		table.insert(spec.steps, {
			id = "linux_luasec",
			kind = "source-build",
			actions = {
				{type = "assert_exists", path = "tree/include/luajit-2.1/lua.h", message = "LuaJIT headers are missing at tree/include/luajit-2.1. Run ./build/make.lua luajit linux first."},
				{type = "download", url = luasec.url, dest = archive},
				{type = "extract", format = "tar.gz", archive = archive, dest = extract, skip_if_exists = true},
				{type = "shell", command = "OPENSSL_LIB=\"" .. prefix .. "/lib\"; [ -f " .. prefix .. "/lib/libssl.so ] || OPENSSL_LIB=\"" .. prefix .. "/lib64\"; bash -lc 'cd " .. extract .. " && gcc -O2 -fPIC -shared -DWITH_LUASOCKET -I${root_abs}/tree/include/luajit-2.1 -I" .. prefix_abs .. "/include -Isrc -Isrc/luasocket src/options.c src/x509.c src/context.c src/ssl.c src/config.c src/ec.c src/luasocket/io.c src/luasocket/buffer.c src/luasocket/timeout.c src/luasocket/usocket.c -o src/ssl.so -L'$OPENSSL_LIB' -Wl,-rpath,\\$ORIGIN -lssl -lcrypto'"},
				{type = "copy", src = extract .. "/src/ssl.so", dst = "${bin_dir}/ssl.so", flags = "-f"},
			},
		})
		table.insert(spec.required_paths, extract)
		table.insert(spec.required_paths, "${bin_dir}/ssl.so")
		table.insert(spec.status_rows, {name = "LUASEC (linux-src)", format = "dl_ex", download = archive, extract = extract})
		table.insert(spec.status_rows, {name = "LUASEC module (linux)", format = "exists", path = "${bin_dir}/ssl.so"})
	end

	local sqlite = deps.sqlite_source and deps.sqlite_source.linux
	if sqlite then
		local archive = "${downloads_dir}/" .. sqlite.archive
		local extract = "${deps_dir}/" .. sqlite.dir
		table.insert(spec.steps, {
			id = "linux_sqlite",
			kind = "source-build",
			actions = {
				{type = "download", url = sqlite.url, dest = archive},
				{type = "extract", format = "tar.gz", archive = archive, dest = extract, skip_if_exists = true},
				{type = "shell", command = "gcc -shared -fPIC -O2 " .. extract .. "/sqlite3.c -o ${bin_dir}/libsqlite3.so -lm -ldl -lpthread"},
			},
		})
		table.insert(spec.required_paths, extract)
		table.insert(spec.required_paths, "${bin_dir}/libsqlite3.so")
		table.insert(spec.status_rows, {name = "SQLITE (linux-src)", format = "dl_ex", download = archive, extract = extract})
		table.insert(spec.status_rows, {name = "SQLITE lib (linux)", format = "exists", path = "${bin_dir}/libsqlite3.so"})
	end

	local fftw = deps.fftw_source and deps.fftw_source.linux
	if fftw then
		local archive = "${downloads_dir}/" .. fftw.archive
		local extract = "${deps_dir}/" .. fftw.dir
		table.insert(spec.steps, {
			id = "linux_fftw",
			kind = "source-build",
			actions = {
				{type = "download", url = fftw.url, dest = archive},
				{type = "extract", format = "tar.gz", archive = archive, dest = extract, skip_if_exists = true},
				{type = "shell", command = Templates.ifMissing(extract .. "/build-cmake/libfftw3.so", "cmake -S " .. extract .. " -B " .. extract .. "/build-cmake -DBUILD_SHARED_LIBS=ON && cmake --build " .. extract .. "/build-cmake -j$(nproc)")},
				{type = "shell", command = "cp -L " .. extract .. "/build-cmake/libfftw3.so ${bin_dir}/libfftw3.so"},
			},
		})
		table.insert(spec.required_paths, extract)
		table.insert(spec.required_paths, "${bin_dir}/libfftw3.so")
		table.insert(spec.status_rows, {name = "FFTW (linux-src)", format = "dl_ex", download = archive, extract = extract})
		table.insert(spec.status_rows, {name = "FFTW lib (linux)", format = "exists", path = "${bin_dir}/libfftw3.so"})
	end

	return spec
end

return Linux
