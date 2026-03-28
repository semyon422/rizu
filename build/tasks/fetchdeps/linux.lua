local Env = require("build.tasks.fetchdeps.env")

local Linux = {}

function Linux.run(env)
	if env.target ~= "linux" then
		return
	end

	local ctx = env.ctx
	local deps = env.deps
	local root_abs = env.root_abs
	local platform_bin = env.platform_bin
	local prefix = "build/deps/local/linux"
	local prefix_abs = root_abs .. "/" .. prefix

	ctx.fs:createDirectory("build/deps/local")
	ctx.fs:createDirectory(prefix)

	local zlib = deps.zlib_source and deps.zlib_source.linux
	if zlib then
		local extract_to = Env.ensure_source_dep(env, zlib)
		if not ctx.fs:getInfo(prefix .. "/lib/libz.so") then
			ctx.shell:execute(string.format("bash -lc 'cd %q && ./configure --prefix=%q'", extract_to, prefix_abs))
			ctx.shell:execute(string.format("bash -lc 'cd %q && make -j$(nproc)'", extract_to))
			ctx.shell:execute(string.format("bash -lc 'cd %q && make install'", extract_to))
		end
		if ctx.fs:getInfo(prefix .. "/lib/libz.so.1") then
			ctx.shell:execute(string.format("cp -Lf %q %q", prefix .. "/lib/libz.so.1", platform_bin .. "/libz.so.1"))
		else
			ctx.shell:execute(string.format("cp -Lf %q %q", prefix .. "/lib/libz.so", platform_bin .. "/libz.so.1"))
		end
		ctx.shell:execute(string.format("rm -f %q", platform_bin .. "/libz.so"))
	end

	local iconv = deps.iconv_source and deps.iconv_source.linux
	if iconv then
		local extract_to = Env.ensure_source_dep(env, iconv)
		if not ctx.fs:getInfo(prefix .. "/lib/libiconv.so") or not ctx.fs:getInfo(prefix .. "/lib/libcharset.so") then
			ctx.shell:execute(string.format("bash -lc 'cd %q && ./configure --prefix=%q --enable-shared --disable-static CFLAGS=\"-fPIC\"'", extract_to, prefix_abs))
			ctx.shell:execute(string.format("bash -lc 'cd %q && make -j$(nproc)'", extract_to))
			ctx.shell:execute(string.format("bash -lc 'cd %q && make install'", extract_to))
		end
		ctx.shell:execute(string.format("cp -Lf %q %q", prefix .. "/lib/libiconv.so", platform_bin .. "/libiconv.so"))
		ctx.shell:execute(string.format("cp -Lf %q %q", prefix .. "/lib/libcharset.so", platform_bin .. "/libcharset.so"))
	end

	local openssl = deps.openssl_source and deps.openssl_source.linux
	if openssl then
		local extract_to = Env.ensure_source_dep(env, openssl)
		local have_ssl_lib = ctx.fs:getInfo(prefix .. "/lib/libssl.so") or ctx.fs:getInfo(prefix .. "/lib64/libssl.so")
		local have_crypto_lib = ctx.fs:getInfo(prefix .. "/lib/libcrypto.so") or ctx.fs:getInfo(prefix .. "/lib64/libcrypto.so")
		if not have_ssl_lib or not have_crypto_lib then
			ctx.shell:execute(string.format(
				"bash -lc 'cd %q && ./Configure linux-x86_64 --prefix=%q --openssldir=%q shared zlib --with-zlib-include=%q --with-zlib-lib=%q'",
				extract_to,
				prefix_abs,
				prefix_abs .. "/ssl",
				prefix_abs .. "/include",
				prefix_abs .. "/lib"
			))
			ctx.shell:execute(string.format("bash -lc 'cd %q && make -j$(nproc)'", extract_to))
			ctx.shell:execute(string.format("bash -lc 'cd %q && make install_sw'", extract_to))
		end
		local openssl_lib_dir = ctx.fs:getInfo(prefix .. "/lib/libssl.so") and (prefix .. "/lib") or (prefix .. "/lib64")
		if ctx.fs:getInfo(openssl_lib_dir .. "/libssl.so.3") then
			ctx.shell:execute(string.format("cp -Lf %q %q", openssl_lib_dir .. "/libssl.so.3", platform_bin .. "/libssl.so.3"))
		else
			ctx.shell:execute(string.format("cp -Lf %q %q", openssl_lib_dir .. "/libssl.so", platform_bin .. "/libssl.so.3"))
		end
		if ctx.fs:getInfo(openssl_lib_dir .. "/libcrypto.so.3") then
			ctx.shell:execute(string.format("cp -Lf %q %q", openssl_lib_dir .. "/libcrypto.so.3", platform_bin .. "/libcrypto.so.3"))
		else
			ctx.shell:execute(string.format("cp -Lf %q %q", openssl_lib_dir .. "/libcrypto.so", platform_bin .. "/libcrypto.so.3"))
		end
		ctx.shell:execute(string.format("rm -f %q %q", platform_bin .. "/libssl.so", platform_bin .. "/libcrypto.so"))
	end

	local luasec = deps.luasec_source and deps.luasec_source.linux
	if luasec then
		local extract_to = Env.ensure_source_dep(env, luasec)
		local luajit_inc = "tree/include/luajit-2.1"
		if not ctx.fs:getInfo(luajit_inc .. "/lua.h") then
			error("LuaJIT headers are missing at " .. luajit_inc .. ". Run ./build/make.lua luajit linux first.")
		end
		local openssl_lib_dir = ctx.fs:getInfo(prefix .. "/lib/libssl.so") and (prefix .. "/lib") or (prefix .. "/lib64")
		ctx.shell:execute(string.format(
			"bash -lc 'cd %q && gcc -O2 -fPIC -shared -DWITH_LUASOCKET -I%q -I%q -Isrc -Isrc/luasocket src/options.c src/x509.c src/context.c src/ssl.c src/config.c src/ec.c src/luasocket/io.c src/luasocket/buffer.c src/luasocket/timeout.c src/luasocket/usocket.c -o src/ssl.so -L%q -Wl,-rpath,\\$$ORIGIN -lssl -lcrypto'",
			extract_to,
			root_abs .. "/" .. luajit_inc,
			root_abs .. "/" .. prefix .. "/include",
			root_abs .. "/" .. openssl_lib_dir
		))
		ctx.shell:execute(string.format("cp -f %q %q", extract_to .. "/src/ssl.so", platform_bin .. "/ssl.so"))
	end

	local sqlite = deps.sqlite_source and deps.sqlite_source.linux
	if sqlite then
		local extract_to = Env.ensure_source_dep(env, sqlite)
		ctx.shell:execute(string.format(
			"gcc -shared -fPIC -O2 %q -o %q -lm -ldl -lpthread",
			extract_to .. "/sqlite3.c",
			platform_bin .. "/libsqlite3.so"
		))
	end

	local fftw = deps.fftw_source and deps.fftw_source.linux
	if fftw then
		local extract_to = Env.ensure_source_dep(env, fftw)
		local build_dir = extract_to .. "/build-cmake"
		local lib_so = platform_bin .. "/libfftw3.so"
		local built_so = build_dir .. "/libfftw3.so"
		if not ctx.fs:getInfo(built_so) then
			ctx.shell:execute(string.format("cmake -S %q -B %q -DBUILD_SHARED_LIBS=ON", extract_to, build_dir))
			ctx.shell:execute(string.format("cmake --build %q -j$(nproc)", build_dir))
		end
		ctx.shell:execute(string.format("cp -L %q %q", built_so, lib_so))
	end
end

return Linux
