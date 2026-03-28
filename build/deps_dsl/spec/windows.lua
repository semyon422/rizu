local Common = require("build.deps_dsl.spec.common")
local Templates = require("build.deps_dsl.spec.Templates")

local Windows = {}

function Windows.build(deps)
	local spec = Common.buildShared("windows", deps)

	local prefix = "${deps_dir}/local/windows"
	local prefix_abs = "${root_abs}/build/deps/local/windows"

	table.insert(spec.steps, {
		id = "windows_prepare_prefix",
		kind = "source-build",
		actions = {
			{type = "ensure_dir", path = "${deps_dir}/local"},
			{type = "ensure_dir", path = prefix},
		},
	})

	local zlib = deps.zlib_source and deps.zlib_source.windows
	if zlib then
		local archive = "${downloads_dir}/" .. zlib.archive
		local extract = "${deps_dir}/" .. zlib.dir
		table.insert(spec.steps, {
			id = "windows_zlib",
			kind = "source-build",
			actions = {
				{type = "download", url = zlib.url, dest = archive},
				{type = "extract", format = "tar.gz", archive = archive, dest = extract, skip_if_exists = true},
				{type = "shell", command = Templates.ifMissing(prefix .. "/bin/zlib1.dll", Templates.bashInDir(extract, "make -f win32/Makefile.gcc clean && make -f win32/Makefile.gcc PREFIX=x86_64-w64-mingw32- SHARED_MODE=1 BINARY_PATH=" .. prefix_abs .. "/bin INCLUDE_PATH=" .. prefix_abs .. "/include LIBRARY_PATH=" .. prefix_abs .. "/lib -j$(nproc)") .. "; mkdir -p " .. prefix .. "/bin; cp -f " .. extract .. "/zlib1.dll " .. prefix .. "/bin/zlib1.dll")},
				{type = "copy", src = prefix .. "/bin/zlib1.dll", dst = "${bin_dir}/z.dll", flags = "-f"},
			},
		})
		table.insert(spec.required_paths, extract)
		table.insert(spec.required_paths, "${bin_dir}/z.dll")
		table.insert(spec.status_rows, {name = "ZLIB (windows-src)", format = "dl_ex", download = archive, extract = extract})
		table.insert(spec.status_rows, {name = "ZLIB lib (windows)", format = "exists", path = "${bin_dir}/z.dll"})
	end

	local iconv = deps.iconv_source and deps.iconv_source.windows
	if iconv then
		local archive = "${downloads_dir}/" .. iconv.archive
		local extract = "${deps_dir}/" .. iconv.dir
		table.insert(spec.steps, {
			id = "windows_iconv",
			kind = "source-build",
			actions = {
				{type = "download", url = iconv.url, dest = archive},
				{type = "extract", format = "tar.gz", archive = archive, dest = extract, skip_if_exists = true},
				{type = "shell", command = "if [ ! -f ${deps_dir}/dd32.sh ]; then cat > ${deps_dir}/dd32.sh <<'DD'\n#!/bin/sh\ncat | head -c 32\nDD\nchmod +x ${deps_dir}/dd32.sh; fi"},
				{type = "shell", command = "if [ ! -f " .. prefix .. "/bin/libiconv-2.dll ]; then bash -lc 'cd " .. extract .. " && ac_cv_path_lt_DD=${root_abs}/${deps_dir}/dd32.sh DD=${root_abs}/${deps_dir}/dd32.sh ./configure --host=x86_64-w64-mingw32 --prefix=" .. prefix_abs .. " --enable-shared --disable-static CFLAGS=\"-O2\" < /dev/null && make -j$(nproc) && make install'; fi"},
				{type = "copy", src = prefix .. "/bin/libiconv-2.dll", dst = "${bin_dir}/libiconv-2.dll", flags = "-f"},
			},
		})
		table.insert(spec.required_paths, extract)
		table.insert(spec.required_paths, "${bin_dir}/libiconv-2.dll")
		table.insert(spec.status_rows, {name = "ICONV (windows-src)", format = "dl_ex", download = archive, extract = extract})
		table.insert(spec.status_rows, {name = "ICONV lib (windows)", format = "exists", path = "${bin_dir}/libiconv-2.dll"})
	end

	local openssl = deps.openssl_source and deps.openssl_source.windows
	if openssl then
		local archive = "${downloads_dir}/" .. openssl.archive
		local extract = "${deps_dir}/" .. openssl.dir
		table.insert(spec.steps, {
			id = "windows_openssl",
			kind = "source-build",
			actions = {
				{type = "download", url = openssl.url, dest = archive},
				{type = "extract", format = "tar.gz", archive = archive, dest = extract, skip_if_exists = true},
				{type = "shell", command = "if [ ! -f " .. prefix .. "/bin/libssl-3-x64.dll ] || [ ! -f " .. prefix .. "/bin/libcrypto-3-x64.dll ]; then bash -lc 'cd " .. extract .. " && ./Configure mingw64 shared --cross-compile-prefix=x86_64-w64-mingw32- --prefix=" .. prefix_abs .. " --openssldir=" .. prefix_abs .. "/ssl && make -j$(nproc) && make install_sw'; fi"},
				{type = "copy", src = prefix .. "/bin/libssl-3-x64.dll", dst = "${bin_dir}/libssl-3-x64.dll", flags = "-f"},
				{type = "copy", src = prefix .. "/bin/libcrypto-3-x64.dll", dst = "${bin_dir}/libcrypto-3-x64.dll", flags = "-f"},
			},
		})
		table.insert(spec.required_paths, extract)
		table.insert(spec.required_paths, "${bin_dir}/libssl-3-x64.dll")
		table.insert(spec.required_paths, "${bin_dir}/libcrypto-3-x64.dll")
		table.insert(spec.status_rows, {name = "OPENSSL (windows-src)", format = "dl_ex", download = archive, extract = extract})
		table.insert(spec.status_rows, {name = "OPENSSL libs (windows)", format = "exists_all", paths = {"${bin_dir}/libssl-3-x64.dll", "${bin_dir}/libcrypto-3-x64.dll"}})
	end

	local luasec = deps.luasec_source and deps.luasec_source.windows
	if luasec then
		local archive = "${downloads_dir}/" .. luasec.archive
		local extract = "${deps_dir}/" .. luasec.dir
		table.insert(spec.steps, {
			id = "windows_luasec",
			kind = "source-build",
			actions = {
				{type = "assert_exists", path = "tree/include/luajit-2.1/lua.h", message = "LuaJIT headers are missing at tree/include/luajit-2.1. Run ./build/make.lua luajit linux first."},
				{type = "assert_exists", path = "tree/lib/libluajit-5.1.dll.a", message = "LuaJIT import lib is missing at tree/lib/libluajit-5.1.dll.a. Run ./build/make.lua luajit windows first."},
				{type = "download", url = luasec.url, dest = archive},
				{type = "extract", format = "tar.gz", archive = archive, dest = extract, skip_if_exists = true},
				{type = "shell", command = "OPENSSL_IMP=\"" .. prefix_abs .. "/lib\"; [ -f " .. prefix .. "/lib/libssl.dll.a ] || OPENSSL_IMP=\"" .. prefix_abs .. "/lib64\"; bash -lc 'cd " .. extract .. " && x86_64-w64-mingw32-gcc -O2 -shared -DWIN32 -DWITH_LUASOCKET -I${root_abs}/tree/include/luajit-2.1 -I" .. prefix_abs .. "/include -Isrc -Isrc/luasocket src/options.c src/x509.c src/context.c src/ssl.c src/config.c src/ec.c src/luasocket/io.c src/luasocket/buffer.c src/luasocket/timeout.c src/luasocket/wsocket.c -o src/ssl.dll -L'$OPENSSL_IMP' -L${root_abs}/tree/lib -lssl -lcrypto -lws2_32 -lcrypt32 -lgdi32 -l:libluajit-5.1.dll.a'"},
				{type = "copy", src = extract .. "/src/ssl.dll", dst = "${bin_dir}/ssl.dll", flags = "-f"},
			},
		})
		table.insert(spec.required_paths, extract)
		table.insert(spec.required_paths, "${bin_dir}/ssl.dll")
		table.insert(spec.status_rows, {name = "LUASEC (windows-src)", format = "dl_ex", download = archive, extract = extract})
		table.insert(spec.status_rows, {name = "LUASEC module (windows)", format = "exists", path = "${bin_dir}/ssl.dll"})
	end

	return spec
end

return Windows
