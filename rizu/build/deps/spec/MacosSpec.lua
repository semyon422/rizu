local Common = require("rizu.build.deps.spec.CommonSpec")

local Macos = {}
local DARWIN_CC = "x86_64-apple-darwin22.2-clang"
local DARWIN_TRIPLE = "x86_64-apple-darwin22.2"

local function add_prepare_prefix(spec, prefix)
	table.insert(spec.steps, {
		id = "macos_prepare_prefix",
		kind = "source-build",
		actions = {
			{type = "assert_exists", path = "build/deps/osxcross/target/bin"},
			{type = "ensure_dir", path = "${deps_dir}/local"},
			{type = "ensure_dir", path = prefix},
			{type = "ensure_dir", path = prefix .. "/lib"},
			{type = "ensure_dir", path = prefix .. "/include"},
		},
	})
end

local function add_ffmpeg(spec, deps, prefix, prefix_abs, tc_bin)
	local ffmpeg_src = deps.ffmpeg_source and deps.ffmpeg_source.macos
	if not ffmpeg_src then
		return
	end
	local archive = "${downloads_dir}/" .. ffmpeg_src.archive
	local extract = "${deps_dir}/" .. ffmpeg_src.dir
	table.insert(spec.steps, {
		id = "macos_ffmpeg_source",
		kind = "source-build",
		actions = {
			{type = "download", url = ffmpeg_src.url, dest = archive},
			{type = "extract", format = "tar.gz", archive = archive, dest = extract, skip_if_exists = true},
			{type = "shell", dir = extract, command = "mkdir -p " .. prefix .. "/ffmpeg; TC=" .. tc_bin .. "/" .. DARWIN_CC .. "; HOST=" .. DARWIN_TRIPLE .. "; AR=" .. tc_bin .. "/$HOST-ar; RANLIB=" .. tc_bin .. "/$HOST-ranlib; export PATH=" .. tc_bin .. ":$PATH; ./configure --prefix=" .. prefix_abs .. "/ffmpeg --enable-cross-compile --target-os=darwin --arch=x86_64 --cc='$TC' --ar='$AR' --ranlib='$RANLIB' --enable-shared --disable-static --disable-programs --disable-doc --disable-debug --disable-asm --disable-videotoolbox && make -j$(nproc) && make install STRIP=true"},
			{type = "assert_file", path = prefix .. "/ffmpeg/lib/libavcodec.dylib"},
			{type = "assert_file", path = prefix .. "/ffmpeg/lib/libavformat.dylib"},
			{type = "assert_file", path = prefix .. "/ffmpeg/lib/libavutil.dylib"},
			{type = "assert_file", path = prefix .. "/ffmpeg/lib/libswscale.dylib"},
			{type = "assert_file", path = prefix .. "/ffmpeg/lib/libswresample.dylib"},
			{type = "copy_exact", src = prefix .. "/ffmpeg/lib/libavcodec.dylib", dst = "${bin_dir}/libavcodec.dylib", flags = "-Lf"},
			{type = "copy_exact", src = prefix .. "/ffmpeg/lib/libavformat.dylib", dst = "${bin_dir}/libavformat.dylib", flags = "-Lf"},
			{type = "copy_exact", src = prefix .. "/ffmpeg/lib/libavutil.dylib", dst = "${bin_dir}/libavutil.dylib", flags = "-Lf"},
			{type = "copy_exact", src = prefix .. "/ffmpeg/lib/libswscale.dylib", dst = "${bin_dir}/libswscale.dylib", flags = "-Lf"},
			{type = "copy_exact", src = prefix .. "/ffmpeg/lib/libswresample.dylib", dst = "${bin_dir}/libswresample.dylib", flags = "-Lf"},
		},
	})
end

local function add_zlib(spec, deps, prefix, prefix_abs, tc_bin)
	local zlib = deps.zlib_source and deps.zlib_source.macos
	if not zlib then
		return
	end
	local archive = "${downloads_dir}/" .. zlib.archive
	local extract = "${deps_dir}/" .. zlib.dir
	table.insert(spec.steps, {
		id = "macos_zlib",
		kind = "source-build",
		actions = {
			{type = "download", url = zlib.url, dest = archive},
			{type = "extract", format = "tar.gz", archive = archive, dest = extract, skip_if_exists = true},
			{type = "shell", command = "TC=" .. tc_bin .. "/" .. DARWIN_CC .. "; bash -lc 'cd " .. extract .. " && '$TC' -dynamiclib -fPIC -O2 -DHAVE_UNISTD_H -install_name @rpath/libz.dylib adler32.c crc32.c deflate.c infback.c inffast.c inflate.c inftrees.c trees.c zutil.c compress.c uncompr.c gzclose.c gzlib.c gzread.c gzwrite.c -o " .. prefix_abs .. "/lib/libz.dylib'; cp -f " .. extract .. "/zlib.h " .. prefix .. "/include/zlib.h; cp -f " .. extract .. "/zconf.h " .. prefix .. "/include/zconf.h"},
			{type = "copy", src = prefix .. "/lib/libz.dylib", dst = "${bin_dir}/libz.dylib", flags = "-f"},
		},
	})
end

local function add_iconv(spec, deps, prefix, prefix_abs, tc_bin)
	local iconv = deps.iconv_source and deps.iconv_source.macos
	if not iconv then
		return
	end
	local archive = "${downloads_dir}/" .. iconv.archive
	local extract = "${deps_dir}/" .. iconv.dir
	table.insert(spec.steps, {
		id = "macos_iconv",
		kind = "source-build",
		actions = {
			{type = "download", url = iconv.url, dest = archive},
			{type = "extract", format = "tar.gz", archive = archive, dest = extract, skip_if_exists = true},
			{type = "write_file", path = "${deps_dir}/dd32.sh", content = "#!/bin/sh\ncat | head -c 32\n"},
			{type = "set_executable", path = "${deps_dir}/dd32.sh"},
			{type = "shell", command = "TC=" .. tc_bin .. "/" .. DARWIN_CC .. "; HOST=" .. DARWIN_TRIPLE .. "; AR=" .. tc_bin .. "/$HOST-ar; RANLIB=" .. tc_bin .. "/$HOST-ranlib; bash -lc 'export PATH=" .. tc_bin .. ":$PATH; cd " .. extract .. " && ac_cv_path_lt_DD=${root_abs}/${deps_dir}/dd32.sh DD=${root_abs}/${deps_dir}/dd32.sh CC='$TC' AR='$AR' RANLIB='$RANLIB' ./configure --host=$HOST --prefix=" .. prefix_abs .. " --enable-shared --disable-static CFLAGS=\"-O2 -fPIC\" < /dev/null && make -j$(nproc) && make install'"},
			{type = "copy", src = prefix .. "/lib/libiconv.dylib", dst = "${bin_dir}/libiconv.dylib", flags = "-f"},
			{type = "copy", src = prefix .. "/lib/libcharset.dylib", dst = "${bin_dir}/libcharset.dylib", flags = "-f"},
		},
	})
end

local function add_openssl(spec, deps, prefix, prefix_abs, tc_bin)
	local openssl = deps.openssl_source and deps.openssl_source.macos
	if not openssl then
		return
	end
	local archive = "${downloads_dir}/" .. openssl.archive
	local extract = "${deps_dir}/" .. openssl.dir
	table.insert(spec.steps, {
		id = "macos_openssl",
		kind = "source-build",
		actions = {
			{type = "download", url = openssl.url, dest = archive},
			{type = "extract", format = "tar.gz", archive = archive, dest = extract, skip_if_exists = true},
			{type = "shell", command = "TC=" .. tc_bin .. "/" .. DARWIN_CC .. "; HOST=" .. DARWIN_TRIPLE .. "; AR=" .. tc_bin .. "/$HOST-ar; RANLIB=" .. tc_bin .. "/$HOST-ranlib; bash -lc 'export PATH=" .. tc_bin .. ":$PATH; cd " .. extract .. " && CC='$TC' AR='$AR' RANLIB='$RANLIB' ./Configure darwin64-x86_64-cc shared --prefix=" .. prefix_abs .. " --openssldir=" .. prefix_abs .. "/ssl && make -j$(nproc) && make install_sw'"},
			{type = "assert_file", path = prefix .. "/lib/libssl.dylib"},
			{type = "assert_file", path = prefix .. "/lib/libcrypto.dylib"},
			{type = "copy_exact", src = prefix .. "/lib/libssl.dylib", dst = "${bin_dir}/libssl.dylib", flags = "-f"},
			{type = "copy_exact", src = prefix .. "/lib/libcrypto.dylib", dst = "${bin_dir}/libcrypto.dylib", flags = "-f"},
		},
	})
end

local function add_luasec(spec, deps, prefix, prefix_abs, tc_bin)
	local luasec = deps.luasec_source and deps.luasec_source.macos
	if not luasec then
		return
	end
	local archive = "${downloads_dir}/" .. luasec.archive
	local extract = "${deps_dir}/" .. luasec.dir
	table.insert(spec.steps, {
		id = "macos_luasec",
		kind = "source-build",
		actions = {
			{type = "assert_exists", path = "tree/include/luajit-2.1/lua.h"},
			{type = "download", url = luasec.url, dest = archive},
			{type = "extract", format = "tar.gz", archive = archive, dest = extract, skip_if_exists = true},
			{type = "assert_file", path = prefix .. "/lib/libssl.dylib"},
			{type = "run_in_dir", dir = extract, command = "TC=" .. tc_bin .. "/" .. DARWIN_CC .. "; export PATH=" .. tc_bin .. ":$PATH; '$TC' -O2 -dynamiclib -undefined dynamic_lookup -DWITH_LUASOCKET -I${root_abs}/tree/include/luajit-2.1 -I" .. prefix_abs .. "/include -Isrc -Isrc/luasocket src/options.c src/x509.c src/context.c src/ssl.c src/config.c src/ec.c src/luasocket/io.c src/luasocket/buffer.c src/luasocket/timeout.c src/luasocket/usocket.c -o src/ssl.dylib -L" .. prefix_abs .. "/lib -Wl,-rpath,@loader_path -lssl -lcrypto"},
			{type = "copy", src = extract .. "/src/ssl.dylib", dst = "${bin_dir}/ssl.dylib", flags = "-f"},
		},
	})
end

function Macos.build(deps)
	local spec = Common.buildShared("macos", deps)
	local prefix = "${deps_dir}/local/macos"
	local prefix_abs = "${root_abs}/build/deps/local/macos"
	local tc_bin = "${root_abs}/build/deps/osxcross/target/bin"

	add_prepare_prefix(spec, prefix)
	add_ffmpeg(spec, deps, prefix, prefix_abs, tc_bin)
	add_zlib(spec, deps, prefix, prefix_abs, tc_bin)
	add_iconv(spec, deps, prefix, prefix_abs, tc_bin)
	add_openssl(spec, deps, prefix, prefix_abs, tc_bin)
	add_luasec(spec, deps, prefix, prefix_abs, tc_bin)

	return spec
end

return Macos
