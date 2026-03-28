local Env = require("build.tasks.fetchdeps.env")

local Windows = {}

function Windows.run(env)
	if env.target ~= "windows" then
		return
	end

	local ctx = env.ctx
	local deps = env.deps
	local root_abs = env.root_abs
	local platform_bin = env.platform_bin
	local prefix = "build/deps/local/windows"
	local prefix_abs = root_abs .. "/" .. prefix
	local cc = "x86_64-w64-mingw32-gcc"
	local dd_wrapper_abs = Env.ensure_dd_wrapper(env)

	ctx.fs:createDirectory("build/deps/local")
	ctx.fs:createDirectory(prefix)

	local zlib = deps.zlib_source and deps.zlib_source.windows
	if zlib then
		local extract_to = Env.ensure_source_dep(env, zlib)
		if not ctx.fs:getInfo(prefix .. "/bin/zlib1.dll") then
			ctx.shell:execute(string.format("bash -lc 'cd %q && make -f win32/Makefile.gcc clean'", extract_to))
			ctx.shell:execute(string.format(
				"bash -lc 'cd %q && make -f win32/Makefile.gcc PREFIX=x86_64-w64-mingw32- SHARED_MODE=1 BINARY_PATH=%q INCLUDE_PATH=%q LIBRARY_PATH=%q -j$(nproc)'",
				extract_to,
				prefix_abs .. "/bin",
				prefix_abs .. "/include",
				prefix_abs .. "/lib"
			))
			ctx.fs:createDirectory(prefix .. "/bin")
			ctx.shell:execute(string.format("cp -f %q %q", extract_to .. "/zlib1.dll", prefix .. "/bin/zlib1.dll"))
		end
		ctx.shell:execute(string.format("cp -f %q %q", prefix .. "/bin/zlib1.dll", platform_bin .. "/z.dll"))
	end

	local iconv = deps.iconv_source and deps.iconv_source.windows
	if iconv then
		local extract_to = Env.ensure_source_dep(env, iconv)
		if not ctx.fs:getInfo(prefix .. "/bin/libiconv-2.dll") then
			ctx.shell:execute(string.format(
				"bash -lc 'cd %q && ac_cv_path_lt_DD=%q DD=%q ./configure --host=x86_64-w64-mingw32 --prefix=%q --enable-shared --disable-static CFLAGS=\"-O2\" < /dev/null'",
				extract_to,
				dd_wrapper_abs,
				dd_wrapper_abs,
				prefix_abs
			))
			ctx.shell:execute(string.format("bash -lc 'cd %q && make -j$(nproc)'", extract_to))
			ctx.shell:execute(string.format("bash -lc 'cd %q && make install'", extract_to))
		end
		ctx.shell:execute(string.format("cp -f %q %q", prefix .. "/bin/libiconv-2.dll", platform_bin .. "/libiconv-2.dll"))
	end

	local openssl = deps.openssl_source and deps.openssl_source.windows
	if openssl then
		local extract_to = Env.ensure_source_dep(env, openssl)
		local have_ssl_lib = ctx.fs:getInfo(prefix .. "/bin/libssl-3-x64.dll")
		local have_crypto_lib = ctx.fs:getInfo(prefix .. "/bin/libcrypto-3-x64.dll")
		if not have_ssl_lib or not have_crypto_lib then
			ctx.shell:execute(string.format(
				"bash -lc 'cd %q && ./Configure mingw64 shared --cross-compile-prefix=x86_64-w64-mingw32- --prefix=%q --openssldir=%q'",
				extract_to,
				prefix_abs,
				prefix_abs .. "/ssl"
			))
			ctx.shell:execute(string.format("bash -lc 'cd %q && make -j$(nproc)'", extract_to))
			ctx.shell:execute(string.format("bash -lc 'cd %q && make install_sw'", extract_to))
		end
		ctx.shell:execute(string.format("cp -f %q %q", prefix .. "/bin/libssl-3-x64.dll", platform_bin .. "/libssl-3-x64.dll"))
		ctx.shell:execute(string.format("cp -f %q %q", prefix .. "/bin/libcrypto-3-x64.dll", platform_bin .. "/libcrypto-3-x64.dll"))
	end

	local luasec = deps.luasec_source and deps.luasec_source.windows
	if luasec then
		local extract_to = Env.ensure_source_dep(env, luasec)
		local luajit_inc = "tree/include/luajit-2.1"
		local luajit_lib = "tree/lib/libluajit-5.1.dll.a"
		if not ctx.fs:getInfo(luajit_inc .. "/lua.h") then
			error("LuaJIT headers are missing at " .. luajit_inc .. ". Run ./build/make.lua luajit linux first.")
		end
		if not ctx.fs:getInfo(luajit_lib) then
			error("LuaJIT import lib is missing at " .. luajit_lib .. ". Run ./build/make.lua luajit windows first.")
		end
		local openssl_imp_dir = ctx.fs:getInfo(prefix .. "/lib/libssl.dll.a") and (prefix_abs .. "/lib") or (prefix_abs .. "/lib64")
		ctx.shell:execute(string.format(
			"bash -lc 'cd %q && %s -O2 -shared -DWIN32 -DWITH_LUASOCKET -I%q -I%q -Isrc -Isrc/luasocket src/options.c src/x509.c src/context.c src/ssl.c src/config.c src/ec.c src/luasocket/io.c src/luasocket/buffer.c src/luasocket/timeout.c src/luasocket/wsocket.c -o src/ssl.dll -L%q -L%q -lssl -lcrypto -lws2_32 -lcrypt32 -lgdi32 -l:libluajit-5.1.dll.a'",
			extract_to,
			cc,
			root_abs .. "/" .. luajit_inc,
			prefix_abs .. "/include",
			openssl_imp_dir,
			root_abs .. "/tree/lib"
		))
		ctx.shell:execute(string.format("cp -f %q %q", extract_to .. "/src/ssl.dll", platform_bin .. "/ssl.dll"))
	end
end

return Windows
