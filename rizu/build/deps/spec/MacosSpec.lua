local Common = require("rizu.build.deps.spec.CommonSpec")
local Dd32Spec = require("rizu.build.deps.spec.common.Dd32Spec")
local table_util = require("aqua.table_util")

local Macos = {}
local DARWIN_CC = "x86_64-apple-darwin22.2-clang"
local DARWIN_TRIPLE = "x86_64-apple-darwin22.2"

local function crossEnv(tc_bin)
	return {
		PATH = tc_bin .. ":$PATH",
		CC = tc_bin .. "/" .. DARWIN_CC,
		AR = tc_bin .. "/" .. DARWIN_TRIPLE .. "-ar",
		RANLIB = tc_bin .. "/" .. DARWIN_TRIPLE .. "-ranlib",
	}
end

local function crossEnvWithDd(tc_bin)
	return Dd32Spec.extendEnv(crossEnv(tc_bin))
end

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
			{type = "ensure_dir", path = prefix .. "/ffmpeg"},
			{
				type = "configure",
				dir = extract,
				env = crossEnv(tc_bin),
				args = {
					"--prefix=" .. prefix_abs .. "/ffmpeg",
					"--enable-cross-compile",
					"--target-os=darwin",
					"--arch=x86_64",
					"--cc=" .. tc_bin .. "/" .. DARWIN_CC,
					"--ar=" .. tc_bin .. "/" .. DARWIN_TRIPLE .. "-ar",
					"--ranlib=" .. tc_bin .. "/" .. DARWIN_TRIPLE .. "-ranlib",
					"--enable-shared",
					"--disable-static",
					"--disable-programs",
					"--disable-doc",
					"--disable-debug",
					"--disable-asm",
					"--disable-videotoolbox",
				},
			},
			{type = "make", dir = extract, env = crossEnv(tc_bin), args = {"-j$(nproc)"}},
			{type = "make", dir = extract, env = crossEnv(tc_bin), args = {"install", "STRIP=true"}},
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
			{
				type = "compile_c",
				compiler = tc_bin .. "/" .. DARWIN_CC,
				dir = extract,
				env = crossEnv(tc_bin),
				cflags = {"-dynamiclib", "-fPIC", "-O2", "-DHAVE_UNISTD_H", "-install_name", "@rpath/libz.dylib"},
				sources = {
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
				},
				output = prefix_abs .. "/lib/libz.dylib",
			},
			{type = "copy_exact", src = extract .. "/zlib.h", dst = prefix .. "/include/zlib.h", flags = "-f"},
			{type = "copy_exact", src = extract .. "/zconf.h", dst = prefix .. "/include/zconf.h", flags = "-f"},
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
	local actions = {
		{type = "download", url = iconv.url, dest = archive},
		{type = "extract", format = "tar.gz", archive = archive, dest = extract, skip_if_exists = true},
	}
	Dd32Spec.addSetup(actions)
	table_util.append(actions, {
		{
			type = "configure",
			dir = extract,
			env = crossEnvWithDd(tc_bin),
			args = {
				"--host=" .. DARWIN_TRIPLE,
				"--prefix=" .. prefix_abs,
				"--enable-shared",
				"--disable-static",
				"CFLAGS=-O2 -fPIC",
			},
		},
		{type = "make", dir = extract, env = crossEnv(tc_bin), args = {"-j$(nproc)"}},
		{type = "make", dir = extract, env = crossEnv(tc_bin), args = {"install"}},
		{type = "copy", src = prefix .. "/lib/libiconv.dylib", dst = "${bin_dir}/libiconv.dylib", flags = "-f"},
		{type = "copy", src = prefix .. "/lib/libcharset.dylib", dst = "${bin_dir}/libcharset.dylib", flags = "-f"},
	})
	table.insert(spec.steps, {
		id = "macos_iconv",
		kind = "source-build",
		actions = actions,
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
			{
				type = "configure",
				dir = extract,
				script = "./Configure",
				env = crossEnv(tc_bin),
				args = {
					"darwin64-x86_64-cc",
					"shared",
					"--prefix=" .. prefix_abs,
					"--openssldir=" .. prefix_abs .. "/ssl",
				},
			},
			{type = "make", dir = extract, env = crossEnv(tc_bin), args = {"-j$(nproc)"}},
			{type = "make", dir = extract, env = crossEnv(tc_bin), args = {"install_sw"}},
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
			{
				type = "compile_c",
				compiler = tc_bin .. "/" .. DARWIN_CC,
				dir = extract,
				env = crossEnv(tc_bin),
				cflags = {"-O2", "-dynamiclib", "-undefined", "dynamic_lookup", "-DWITH_LUASOCKET"},
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
					"src/luasocket/usocket.c",
				},
				output = "src/ssl.dylib",
				lib_dirs = {prefix_abs .. "/lib"},
				libs = {"ssl", "crypto"},
				ldflags = {"-Wl,-rpath,@loader_path"},
			},
			{type = "copy", src = extract .. "/src/ssl.dylib", dst = "${bin_dir}/ssl.dylib", flags = "-f"},
		},
	})
end

local function add_fftw(spec, deps, prefix, prefix_abs, tc_bin)
	local fftw = deps.fftw_source and deps.fftw_source.macos
	if not fftw then
		return
	end
	local archive = "${downloads_dir}/" .. fftw.archive
	local extract = "${deps_dir}/" .. fftw.dir
	local actions = {
		{type = "download", url = fftw.url, dest = archive},
		{type = "extract", format = "tar.gz", archive = archive, dest = extract, skip_if_exists = true},
	}
	Dd32Spec.addSetup(actions)
	table_util.append(actions, {
		{
			type = "configure",
			dir = extract,
			env = crossEnvWithDd(tc_bin),
			args = {"--host=" .. DARWIN_TRIPLE, "--prefix=" .. prefix_abs, "--enable-shared", "--disable-static", "CFLAGS=-O2 -fPIC"},
		},
		{type = "make", dir = extract, env = crossEnv(tc_bin), args = {"-j$(nproc)"}},
		{type = "make", dir = extract, env = crossEnv(tc_bin), args = {"install"}},
		{type = "assert_file", path = prefix .. "/lib/libfftw3.dylib"},
		{type = "copy_exact", src = prefix .. "/lib/libfftw3.dylib", dst = "${bin_dir}/libfftw3.dylib", flags = "-Lf"},
	})
	table.insert(spec.steps, {
		id = "macos_fftw",
		kind = "source-build",
		actions = actions,
	})
end

local function add_sqlite(spec, deps, tc_bin)
	local sqlite = deps.sqlite_source and deps.sqlite_source.macos
	if not sqlite then
		return
	end
	local archive = "${downloads_dir}/" .. sqlite.archive
	local extract = "${deps_dir}/" .. sqlite.dir
	table.insert(spec.steps, {
		id = "macos_sqlite",
		kind = "source-build",
		actions = {
			{type = "download", url = sqlite.url, dest = archive},
			{type = "extract", format = "tar.gz", archive = archive, dest = extract, skip_if_exists = true},
			{
				type = "compile_c",
				compiler = tc_bin .. "/" .. DARWIN_CC,
				env = crossEnv(tc_bin),
				cflags = {"-dynamiclib", "-fPIC", "-O2", "-install_name", "@rpath/libsqlite3.dylib"},
				sources = {extract .. "/sqlite3.c"},
				output = "${bin_dir}/libsqlite3.dylib",
			},
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
	add_fftw(spec, deps, prefix, prefix_abs, tc_bin)
	add_sqlite(spec, deps, tc_bin)

	return spec
end

return Macos
