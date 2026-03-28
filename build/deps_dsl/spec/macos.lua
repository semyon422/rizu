local Common = require("build.deps_dsl.spec.common")
local Templates = require("build.deps_dsl.spec.Templates")

local Macos = {}

function Macos.build(deps)
	local spec = Common.buildShared("macos", deps)

	local prefix = "${deps_dir}/local/macos"
	local prefix_abs = "${root_abs}/build/deps/local/macos"
	local tc_bin = "${root_abs}/build/deps/osxcross/target/bin"

	table.insert(spec.steps, {
		id = "macos_prepare_prefix",
		kind = "source-build",
		actions = {
			{type = "assert_exists", path = "build/deps/osxcross/target/bin", message = "macOS osxcross compiler not found. Run ./build/make.lua macos_toolchain"},
			{type = "ensure_dir", path = "${deps_dir}/local"},
			{type = "ensure_dir", path = prefix},
			{type = "ensure_dir", path = prefix .. "/lib"},
			{type = "ensure_dir", path = prefix .. "/include"},
		},
	})

	local ffmpeg_src = deps.ffmpeg_source and deps.ffmpeg_source.macos
	if ffmpeg_src then
		local archive = "${downloads_dir}/" .. ffmpeg_src.archive
		local extract = "${deps_dir}/" .. ffmpeg_src.dir
		table.insert(spec.steps, {
			id = "macos_ffmpeg_source",
			kind = "source-build",
			actions = {
				{type = "download", url = ffmpeg_src.url, dest = archive},
				{type = "extract", format = "tar.gz", archive = archive, dest = extract, skip_if_exists = true},
				{type = "shell", command = Templates.ifMissing(prefix .. "/ffmpeg/lib/libavcodec.dylib", "mkdir -p " .. prefix .. "/ffmpeg; TC=$(ls " .. tc_bin .. "/x86_64-apple-darwin*-clang 2>/dev/null | head -n1); HOST=$(basename $TC | sed 's/-clang$//'); AR=" .. tc_bin .. "/$HOST-ar; RANLIB=" .. tc_bin .. "/$HOST-ranlib; " .. Templates.bashInDir(extract, "export PATH=" .. tc_bin .. ":$PATH; ./configure --prefix=" .. prefix_abs .. "/ffmpeg --enable-cross-compile --target-os=darwin --arch=x86_64 --cc='$TC' --ar='$AR' --ranlib='$RANLIB' --enable-shared --disable-static --disable-programs --disable-doc --disable-debug --disable-asm --disable-videotoolbox && make -j$(nproc) && make install STRIP=true"))},
				{type = "shell", command = "for lib in libavcodec.dylib libavformat.dylib libavutil.dylib libswscale.dylib libswresample.dylib libavfilter.dylib libavdevice.dylib; do [ -f " .. prefix .. "/ffmpeg/lib/$lib ] && cp -Lf " .. prefix .. "/ffmpeg/lib/$lib ${bin_dir}/$lib; done"},
			},
		})
		table.insert(spec.required_paths, extract)
		table.insert(spec.required_paths, "${bin_dir}/libavcodec.dylib")
		table.insert(spec.required_paths, "${bin_dir}/libavformat.dylib")
		table.insert(spec.required_paths, "${bin_dir}/libavutil.dylib")
		table.insert(spec.required_paths, "${bin_dir}/libswscale.dylib")
		table.insert(spec.required_paths, "${bin_dir}/libswresample.dylib")
		table.insert(spec.status_rows, {name = "FFMPEG (macos-src)", format = "dl_ex", download = archive, extract = extract})
		table.insert(spec.status_rows, {name = "FFMPEG libs (macos)", format = "exists_all", paths = {"${bin_dir}/libavcodec.dylib", "${bin_dir}/libavformat.dylib", "${bin_dir}/libavutil.dylib", "${bin_dir}/libswscale.dylib", "${bin_dir}/libswresample.dylib"}})
	end

	local zlib = deps.zlib_source and deps.zlib_source.macos
	if zlib then
		local archive = "${downloads_dir}/" .. zlib.archive
		local extract = "${deps_dir}/" .. zlib.dir
		table.insert(spec.steps, {
			id = "macos_zlib",
			kind = "source-build",
			actions = {
				{type = "download", url = zlib.url, dest = archive},
				{type = "extract", format = "tar.gz", archive = archive, dest = extract, skip_if_exists = true},
				{type = "shell", command = "if [ ! -f " .. prefix .. "/lib/libz.dylib ]; then TC=$(ls " .. tc_bin .. "/x86_64-apple-darwin*-clang 2>/dev/null | head -n1); bash -lc 'cd " .. extract .. " && '$TC' -dynamiclib -fPIC -O2 -DHAVE_UNISTD_H -install_name @rpath/libz.dylib adler32.c crc32.c deflate.c infback.c inffast.c inflate.c inftrees.c trees.c zutil.c compress.c uncompr.c gzclose.c gzlib.c gzread.c gzwrite.c -o " .. prefix_abs .. "/lib/libz.dylib'; cp -f " .. extract .. "/zlib.h " .. prefix .. "/include/zlib.h; cp -f " .. extract .. "/zconf.h " .. prefix .. "/include/zconf.h; fi"},
				{type = "copy", src = prefix .. "/lib/libz.dylib", dst = "${bin_dir}/libz.dylib", flags = "-f"},
			},
		})
		table.insert(spec.required_paths, extract)
		table.insert(spec.required_paths, "${bin_dir}/libz.dylib")
		table.insert(spec.status_rows, {name = "ZLIB (macos-src)", format = "dl_ex", download = archive, extract = extract})
		table.insert(spec.status_rows, {name = "ZLIB lib (macos)", format = "exists", path = "${bin_dir}/libz.dylib"})
	end

	local iconv = deps.iconv_source and deps.iconv_source.macos
	if iconv then
		local archive = "${downloads_dir}/" .. iconv.archive
		local extract = "${deps_dir}/" .. iconv.dir
		table.insert(spec.steps, {
			id = "macos_iconv",
			kind = "source-build",
			actions = {
				{type = "download", url = iconv.url, dest = archive},
				{type = "extract", format = "tar.gz", archive = archive, dest = extract, skip_if_exists = true},
				{type = "shell", command = "if [ ! -f ${deps_dir}/dd32.sh ]; then cat > ${deps_dir}/dd32.sh <<'DD'\n#!/bin/sh\ncat | head -c 32\nDD\nchmod +x ${deps_dir}/dd32.sh; fi"},
				{type = "shell", command = "if [ ! -f " .. prefix .. "/lib/libiconv.dylib ] || [ ! -f " .. prefix .. "/lib/libcharset.dylib ]; then TC=$(ls " .. tc_bin .. "/x86_64-apple-darwin*-clang 2>/dev/null | head -n1); HOST=$(basename $TC | sed 's/-clang$//'); AR=" .. tc_bin .. "/$HOST-ar; RANLIB=" .. tc_bin .. "/$HOST-ranlib; bash -lc 'export PATH=" .. tc_bin .. ":$PATH; cd " .. extract .. " && ac_cv_path_lt_DD=${root_abs}/${deps_dir}/dd32.sh DD=${root_abs}/${deps_dir}/dd32.sh CC='$TC' AR='$AR' RANLIB='$RANLIB' ./configure --host=$HOST --prefix=" .. prefix_abs .. " --enable-shared --disable-static CFLAGS=\"-O2 -fPIC\" < /dev/null && make -j$(nproc) && make install'; fi"},
				{type = "copy", src = prefix .. "/lib/libiconv.dylib", dst = "${bin_dir}/libiconv.dylib", flags = "-f"},
				{type = "copy", src = prefix .. "/lib/libcharset.dylib", dst = "${bin_dir}/libcharset.dylib", flags = "-f"},
			},
		})
		table.insert(spec.required_paths, extract)
		table.insert(spec.required_paths, "${bin_dir}/libiconv.dylib")
		table.insert(spec.required_paths, "${bin_dir}/libcharset.dylib")
		table.insert(spec.status_rows, {name = "ICONV (macos-src)", format = "dl_ex", download = archive, extract = extract})
		table.insert(spec.status_rows, {name = "ICONV libs (macos)", format = "exists_all", paths = {"${bin_dir}/libiconv.dylib", "${bin_dir}/libcharset.dylib"}})
	end

	local openssl = deps.openssl_source and deps.openssl_source.macos
	if openssl then
		local archive = "${downloads_dir}/" .. openssl.archive
		local extract = "${deps_dir}/" .. openssl.dir
		table.insert(spec.steps, {
			id = "macos_openssl",
			kind = "source-build",
			actions = {
				{type = "download", url = openssl.url, dest = archive},
				{type = "extract", format = "tar.gz", archive = archive, dest = extract, skip_if_exists = true},
				{type = "shell", command = "if [ ! -f " .. prefix .. "/lib/libssl.dylib ] && [ ! -f " .. prefix .. "/lib64/libssl.dylib ]; then TC=$(ls " .. tc_bin .. "/x86_64-apple-darwin*-clang 2>/dev/null | head -n1); HOST=$(basename $TC | sed 's/-clang$//'); AR=" .. tc_bin .. "/$HOST-ar; RANLIB=" .. tc_bin .. "/$HOST-ranlib; bash -lc 'export PATH=" .. tc_bin .. ":$PATH; cd " .. extract .. " && CC='$TC' AR='$AR' RANLIB='$RANLIB' ./Configure darwin64-x86_64-cc shared --prefix=" .. prefix_abs .. " --openssldir=" .. prefix_abs .. "/ssl && make -j$(nproc) && make install_sw'; fi"},
				{type = "shell", command = "OPENSSL_LIB=\"" .. prefix .. "/lib\"; [ -f " .. prefix .. "/lib/libssl.dylib ] || OPENSSL_LIB=\"" .. prefix .. "/lib64\"; cp -f $OPENSSL_LIB/libssl.dylib ${bin_dir}/libssl.dylib; cp -f $OPENSSL_LIB/libcrypto.dylib ${bin_dir}/libcrypto.dylib"},
			},
		})
		table.insert(spec.required_paths, extract)
		table.insert(spec.required_paths, "${bin_dir}/libssl.dylib")
		table.insert(spec.required_paths, "${bin_dir}/libcrypto.dylib")
		table.insert(spec.status_rows, {name = "OPENSSL (macos-src)", format = "dl_ex", download = archive, extract = extract})
		table.insert(spec.status_rows, {name = "OPENSSL libs (macos)", format = "exists_all", paths = {"${bin_dir}/libssl.dylib", "${bin_dir}/libcrypto.dylib"}})
	end

	local luasec = deps.luasec_source and deps.luasec_source.macos
	if luasec then
		local archive = "${downloads_dir}/" .. luasec.archive
		local extract = "${deps_dir}/" .. luasec.dir
		table.insert(spec.steps, {
			id = "macos_luasec",
			kind = "source-build",
			actions = {
				{type = "assert_exists", path = "tree/include/luajit-2.1/lua.h", message = "LuaJIT headers are missing at tree/include/luajit-2.1. Run ./build/make.lua luajit linux first."},
				{type = "download", url = luasec.url, dest = archive},
				{type = "extract", format = "tar.gz", archive = archive, dest = extract, skip_if_exists = true},
				{type = "shell", command = "OPENSSL_LIB=\"" .. prefix_abs .. "/lib\"; [ -f " .. prefix .. "/lib/libssl.dylib ] || OPENSSL_LIB=\"" .. prefix_abs .. "/lib64\"; TC=$(ls " .. tc_bin .. "/x86_64-apple-darwin*-clang 2>/dev/null | head -n1); bash -lc 'export PATH=" .. tc_bin .. ":$PATH; cd " .. extract .. " && '$TC' -O2 -dynamiclib -undefined dynamic_lookup -DWITH_LUASOCKET -I${root_abs}/tree/include/luajit-2.1 -I" .. prefix_abs .. "/include -Isrc -Isrc/luasocket src/options.c src/x509.c src/context.c src/ssl.c src/config.c src/ec.c src/luasocket/io.c src/luasocket/buffer.c src/luasocket/timeout.c src/luasocket/usocket.c -o src/ssl.dylib -L'$OPENSSL_LIB' -Wl,-rpath,@loader_path -lssl -lcrypto'"},
				{type = "copy", src = extract .. "/src/ssl.dylib", dst = "${bin_dir}/ssl.dylib", flags = "-f"},
			},
		})
		table.insert(spec.required_paths, extract)
		table.insert(spec.required_paths, "${bin_dir}/ssl.dylib")
		table.insert(spec.status_rows, {name = "LUASEC (macos-src)", format = "dl_ex", download = archive, extract = extract})
		table.insert(spec.status_rows, {name = "LUASEC module (macos)", format = "exists", path = "${bin_dir}/ssl.dylib"})
	end

	return spec
end

return Macos
