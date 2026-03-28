local Env = require("build.tasks.fetchdeps.env")

local Macos = {}

function Macos.run(env)
	if env.target ~= "macos" then
		return
	end

	local ctx = env.ctx
	local deps = env.deps
	local root_abs = env.root_abs
	local platform_bin = env.platform_bin

	local tc = Env.resolve_macos_toolchain(env)
	if not tc then
		error("macOS osxcross compiler not found. Run ./build/make.lua macos_toolchain")
	end
	local install_name_tool_rel = tc.install_name_tool:gsub("^" .. root_abs .. "/", "")
	if not ctx.fs:getInfo(install_name_tool_rel) then
		error("macOS osxcross install_name_tool not found at " .. tc.install_name_tool)
	end

	local tc_bin = root_abs .. "/build/deps/osxcross/target/bin"
	local dd_wrapper_abs = Env.ensure_dd_wrapper(env)
	local prefix = "build/deps/local/macos"
	local prefix_abs = root_abs .. "/" .. prefix

	ctx.fs:createDirectory("build/deps/local")
	ctx.fs:createDirectory(prefix)
	ctx.fs:createDirectory(prefix .. "/lib")
	ctx.fs:createDirectory(prefix .. "/include")

	local ffmpeg_src = deps.ffmpeg_source and deps.ffmpeg_source.macos
	if ffmpeg_src then
		local extract_to = Env.ensure_source_dep(env, ffmpeg_src)
		if not ctx.fs:getInfo(extract_to .. "/configure") then
			ctx.fs:remove(extract_to)
			extract_to = Env.ensure_source_dep(env, ffmpeg_src)
		end
		local ff_prefix = prefix_abs .. "/ffmpeg"
		if not ctx.fs:getInfo(ff_prefix .. "/lib/libavcodec.dylib") then
			ctx.fs:createDirectory(prefix .. "/ffmpeg")
			ctx.shell:execute(string.format(
				"bash -lc 'export PATH=%q:$PATH; cd %q && ./configure --prefix=%q --enable-cross-compile --target-os=darwin --arch=x86_64 --cc=%q --ar=%q --ranlib=%q --enable-shared --disable-static --disable-programs --disable-doc --disable-debug --disable-asm --disable-videotoolbox'",
				tc_bin,
				extract_to,
				ff_prefix,
				tc.cc,
				tc.ar,
				tc.ranlib
			))
			ctx.shell:execute(string.format("bash -lc 'export PATH=%q:$PATH; cd %q && make -j$(nproc)'", tc_bin, extract_to))
			ctx.shell:execute(string.format("bash -lc 'export PATH=%q:$PATH; cd %q && make install STRIP=true'", tc_bin, extract_to))
		end
		local ff_libs = {
			"libavcodec.dylib",
			"libavformat.dylib",
			"libavutil.dylib",
			"libswscale.dylib",
			"libswresample.dylib",
			"libavfilter.dylib",
			"libavdevice.dylib",
		}
		for _, lib in ipairs(ff_libs) do
			if ctx.fs:getInfo(prefix .. "/ffmpeg/lib/" .. lib) then
				ctx.shell:execute(string.format("cp -Lf %q %q", prefix .. "/ffmpeg/lib/" .. lib, platform_bin .. "/" .. lib))
			end
		end

		local ff_lib_abs = ff_prefix .. "/lib"
		local ff_tool = tc.install_name_tool
		ctx.shell:execute(string.format("%q -id @loader_path/libavutil.dylib %q", ff_tool, platform_bin .. "/libavutil.dylib"))
		ctx.shell:execute(string.format("%q -id @loader_path/libswresample.dylib %q", ff_tool, platform_bin .. "/libswresample.dylib"))
		ctx.shell:execute(string.format("%q -id @loader_path/libswscale.dylib %q", ff_tool, platform_bin .. "/libswscale.dylib"))
		ctx.shell:execute(string.format("%q -id @loader_path/libavcodec.dylib %q", ff_tool, platform_bin .. "/libavcodec.dylib"))
		ctx.shell:execute(string.format("%q -id @loader_path/libavformat.dylib %q", ff_tool, platform_bin .. "/libavformat.dylib"))
		ctx.shell:execute(string.format("%q -id @loader_path/libavfilter.dylib %q", ff_tool, platform_bin .. "/libavfilter.dylib"))
		ctx.shell:execute(string.format("%q -id @loader_path/libavdevice.dylib %q", ff_tool, platform_bin .. "/libavdevice.dylib"))

		ctx.shell:execute(string.format("%q -change %q @loader_path/libavutil.dylib %q", ff_tool, ff_lib_abs .. "/libavutil.59.dylib", platform_bin .. "/libswresample.dylib"))
		ctx.shell:execute(string.format("%q -change %q @loader_path/libavutil.dylib %q", ff_tool, ff_lib_abs .. "/libavutil.59.dylib", platform_bin .. "/libswscale.dylib"))
		ctx.shell:execute(string.format("%q -change %q @loader_path/libswresample.dylib %q", ff_tool, ff_lib_abs .. "/libswresample.5.dylib", platform_bin .. "/libavcodec.dylib"))
		ctx.shell:execute(string.format("%q -change %q @loader_path/libavutil.dylib %q", ff_tool, ff_lib_abs .. "/libavutil.59.dylib", platform_bin .. "/libavcodec.dylib"))
		ctx.shell:execute(string.format("%q -change %q @loader_path/libavcodec.dylib %q", ff_tool, ff_lib_abs .. "/libavcodec.61.dylib", platform_bin .. "/libavformat.dylib"))
		ctx.shell:execute(string.format("%q -change %q @loader_path/libswresample.dylib %q", ff_tool, ff_lib_abs .. "/libswresample.5.dylib", platform_bin .. "/libavformat.dylib"))
		ctx.shell:execute(string.format("%q -change %q @loader_path/libavutil.dylib %q", ff_tool, ff_lib_abs .. "/libavutil.59.dylib", platform_bin .. "/libavformat.dylib"))
		ctx.shell:execute(string.format("%q -change %q @loader_path/libavformat.dylib %q", ff_tool, ff_lib_abs .. "/libavformat.61.dylib", platform_bin .. "/libavfilter.dylib"))
		ctx.shell:execute(string.format("%q -change %q @loader_path/libavcodec.dylib %q", ff_tool, ff_lib_abs .. "/libavcodec.61.dylib", platform_bin .. "/libavfilter.dylib"))
		ctx.shell:execute(string.format("%q -change %q @loader_path/libswscale.dylib %q", ff_tool, ff_lib_abs .. "/libswscale.8.dylib", platform_bin .. "/libavfilter.dylib"))
		ctx.shell:execute(string.format("%q -change %q @loader_path/libswresample.dylib %q", ff_tool, ff_lib_abs .. "/libswresample.5.dylib", platform_bin .. "/libavfilter.dylib"))
		ctx.shell:execute(string.format("%q -change %q @loader_path/libavutil.dylib %q", ff_tool, ff_lib_abs .. "/libavutil.59.dylib", platform_bin .. "/libavfilter.dylib"))
		ctx.shell:execute(string.format("%q -change %q @loader_path/libavfilter.dylib %q", ff_tool, ff_lib_abs .. "/libavfilter.10.dylib", platform_bin .. "/libavdevice.dylib"))
		ctx.shell:execute(string.format("%q -change %q @loader_path/libavformat.dylib %q", ff_tool, ff_lib_abs .. "/libavformat.61.dylib", platform_bin .. "/libavdevice.dylib"))
		ctx.shell:execute(string.format("%q -change %q @loader_path/libavcodec.dylib %q", ff_tool, ff_lib_abs .. "/libavcodec.61.dylib", platform_bin .. "/libavdevice.dylib"))
		ctx.shell:execute(string.format("%q -change %q @loader_path/libavutil.dylib %q", ff_tool, ff_lib_abs .. "/libavutil.59.dylib", platform_bin .. "/libavdevice.dylib"))
		ctx.shell:execute(string.format("%q -change %q @loader_path/libswscale.dylib %q", ff_tool, ff_lib_abs .. "/libswscale.8.dylib", platform_bin .. "/libavdevice.dylib"))
		ctx.shell:execute(string.format("%q -change %q @loader_path/libswresample.dylib %q", ff_tool, ff_lib_abs .. "/libswresample.5.dylib", platform_bin .. "/libavdevice.dylib"))
	end

	local zlib = deps.zlib_source and deps.zlib_source.macos
	if zlib then
		local extract_to = Env.ensure_source_dep(env, zlib)
		if not ctx.fs:getInfo(prefix .. "/lib/libz.dylib") then
			local zsrc = table.concat({
				"adler32.c", "crc32.c", "deflate.c", "infback.c", "inffast.c", "inflate.c", "inftrees.c",
				"trees.c", "zutil.c", "compress.c", "uncompr.c", "gzclose.c", "gzlib.c", "gzread.c", "gzwrite.c",
			}, " ")
			ctx.shell:execute(string.format(
				"bash -lc 'export PATH=%q:$PATH; cd %q && %q -dynamiclib -fPIC -O2 -DHAVE_UNISTD_H -install_name @rpath/libz.dylib %s -o %q'",
				tc_bin,
				extract_to,
				tc.cc,
				zsrc,
				prefix_abs .. "/lib/libz.dylib"
			))
			ctx.shell:execute(string.format("cp -f %q %q", extract_to .. "/zlib.h", prefix .. "/include/zlib.h"))
			ctx.shell:execute(string.format("cp -f %q %q", extract_to .. "/zconf.h", prefix .. "/include/zconf.h"))
		end
		ctx.shell:execute(string.format("cp -f %q %q", prefix .. "/lib/libz.dylib", platform_bin .. "/libz.dylib"))
	end

	local iconv = deps.iconv_source and deps.iconv_source.macos
	if iconv then
		local extract_to = Env.ensure_source_dep(env, iconv)
		if not ctx.fs:getInfo(prefix .. "/lib/libiconv.dylib") or not ctx.fs:getInfo(prefix .. "/lib/libcharset.dylib") then
			ctx.shell:execute(string.format(
				"bash -lc 'export PATH=%q:$PATH; cd %q && ac_cv_path_lt_DD=%q DD=%q CC=%q AR=%q RANLIB=%q ./configure --host=%q --prefix=%q --enable-shared --disable-static CFLAGS=\"-O2 -fPIC\" < /dev/null'",
				tc_bin,
				extract_to,
				dd_wrapper_abs,
				dd_wrapper_abs,
				tc.cc,
				tc.ar,
				tc.ranlib,
				tc.host,
				prefix_abs
			))
			ctx.shell:execute(string.format("bash -lc 'export PATH=%q:$PATH; cd %q && make -j$(nproc)'", tc_bin, extract_to))
			ctx.shell:execute(string.format("bash -lc 'export PATH=%q:$PATH; cd %q && make install'", tc_bin, extract_to))
		end
		ctx.shell:execute(string.format("cp -f %q %q", prefix .. "/lib/libiconv.dylib", platform_bin .. "/libiconv.dylib"))
		ctx.shell:execute(string.format("cp -f %q %q", prefix .. "/lib/libcharset.dylib", platform_bin .. "/libcharset.dylib"))
	end

	local openssl = deps.openssl_source and deps.openssl_source.macos
	if openssl then
		local extract_to = Env.ensure_source_dep(env, openssl)
		local have_ssl_lib = ctx.fs:getInfo(prefix .. "/lib/libssl.dylib") or ctx.fs:getInfo(prefix .. "/lib64/libssl.dylib")
		local have_crypto_lib = ctx.fs:getInfo(prefix .. "/lib/libcrypto.dylib") or ctx.fs:getInfo(prefix .. "/lib64/libcrypto.dylib")
		if not have_ssl_lib or not have_crypto_lib then
			ctx.shell:execute(string.format(
				"bash -lc 'export PATH=%q:$PATH; cd %q && CC=%q AR=%q RANLIB=%q ./Configure darwin64-x86_64-cc shared --prefix=%q --openssldir=%q'",
				tc_bin,
				extract_to,
				tc.cc,
				tc.ar,
				tc.ranlib,
				prefix_abs,
				prefix_abs .. "/ssl"
			))
			ctx.shell:execute(string.format("bash -lc 'export PATH=%q:$PATH; cd %q && make -j$(nproc)'", tc_bin, extract_to))
			ctx.shell:execute(string.format("bash -lc 'export PATH=%q:$PATH; cd %q && make install_sw'", tc_bin, extract_to))
		end
		local openssl_lib_dir = ctx.fs:getInfo(prefix .. "/lib/libssl.dylib") and (prefix .. "/lib") or (prefix .. "/lib64")
		local openssl_lib_dir_abs = root_abs .. "/" .. openssl_lib_dir
		ctx.shell:execute(string.format("cp -f %q %q", openssl_lib_dir .. "/libssl.dylib", platform_bin .. "/libssl.dylib"))
		ctx.shell:execute(string.format("cp -f %q %q", openssl_lib_dir .. "/libcrypto.dylib", platform_bin .. "/libcrypto.dylib"))
		ctx.shell:execute(string.format("%q -id @loader_path/libcrypto.dylib %q", tc.install_name_tool, platform_bin .. "/libcrypto.dylib"))
		ctx.shell:execute(string.format("%q -id @loader_path/libssl.dylib %q", tc.install_name_tool, platform_bin .. "/libssl.dylib"))
		ctx.shell:execute(string.format("%q -change %q @loader_path/libcrypto.dylib %q", tc.install_name_tool, openssl_lib_dir_abs .. "/libcrypto.3.dylib", platform_bin .. "/libssl.dylib"))
	end

	local luasec = deps.luasec_source and deps.luasec_source.macos
	if luasec then
		local extract_to = Env.ensure_source_dep(env, luasec)
		local luajit_inc = "tree/include/luajit-2.1"
		if not ctx.fs:getInfo(luajit_inc .. "/lua.h") then
			error("LuaJIT headers are missing at " .. luajit_inc .. ". Run ./build/make.lua luajit linux first.")
		end
		local openssl_lib_dir = ctx.fs:getInfo(prefix .. "/lib/libssl.dylib") and (prefix_abs .. "/lib") or (prefix_abs .. "/lib64")
		ctx.shell:execute(string.format(
			"bash -lc 'export PATH=%q:$PATH; cd %q && %q -O2 -dynamiclib -undefined dynamic_lookup -DWITH_LUASOCKET -I%q -I%q -Isrc -Isrc/luasocket src/options.c src/x509.c src/context.c src/ssl.c src/config.c src/ec.c src/luasocket/io.c src/luasocket/buffer.c src/luasocket/timeout.c src/luasocket/usocket.c -o src/ssl.dylib -L%q -Wl,-rpath,@loader_path -lssl -lcrypto'",
			tc_bin,
			extract_to,
			tc.cc,
			root_abs .. "/" .. luajit_inc,
			prefix_abs .. "/include",
			openssl_lib_dir
		))
		ctx.shell:execute(string.format("cp -f %q %q", extract_to .. "/src/ssl.dylib", platform_bin .. "/ssl.dylib"))
		ctx.shell:execute(string.format("%q -change %q @loader_path/libssl.dylib %q", tc.install_name_tool, openssl_lib_dir .. "/libssl.3.dylib", platform_bin .. "/ssl.dylib"))
		ctx.shell:execute(string.format("%q -change %q @loader_path/libcrypto.dylib %q", tc.install_name_tool, openssl_lib_dir .. "/libcrypto.3.dylib", platform_bin .. "/ssl.dylib"))
	end
end

return Macos
