local class = require("class")
local deps = require("build.deps")

---@class build.tasks.FetchDeps
local FetchDeps = class()

function FetchDeps:new(target)
	self.name = "deps_" .. target
	self.target = target
	self.deps = {}
end

function FetchDeps:run(ctx)
	local target = self.target:lower()
	local root_abs = ctx.shell:popen("pwd"):gsub("%s+$", "")
	ctx.fs:createDirectory("build/downloads")
	ctx.fs:createDirectory("build/deps")
	ctx.fs:createDirectory("build/downloads/prebuilt")
	ctx.fs:createDirectory("build/downloads/prebuilt/" .. target)

	local platform_bin_map = {
		linux   = "bin/linux64",
		windows = "bin/win64",
		macos   = "bin/mac64",
	}
	local platform_bin = platform_bin_map[target] or platform_bin_map.linux
	ctx.fs:createDirectory(platform_bin)

	local function ensure_source_dep(config)
		local dest = "build/downloads/" .. config.archive
		local extract_to = "build/deps/" .. config.dir
		if not ctx.fs:getInfo(extract_to) then
			if not ctx.fs:getInfo(dest) or ctx.fs:getInfo(dest).size == 0 then
				ctx.downloader:download(config.url, dest)
			end
			ctx.fs:createDirectory(extract_to)
			if config.archive:match("%.tar%.gz$") or config.archive:match("%.tgz$") then
				ctx.shell:execute(string.format("tar -xzf %q -C %q --strip-components=1", dest, extract_to))
			elseif config.archive:match("%.tar%.xz$") then
				ctx.shell:execute(string.format("tar -xf %q -C %q --strip-components=1", dest, extract_to))
			else
				error("Unsupported source archive format: " .. config.archive)
			end
		end
		return extract_to
	end

	-- 1. Process FFmpeg
	local ffmpeg = deps.ffmpeg[target]
	if ffmpeg then
		local dest = "build/downloads/" .. ffmpeg.archive
		local extract_to = "build/deps/" .. ffmpeg.dir
		local extracted = ctx.fs:getInfo(extract_to)
		if not extracted then
			if not ctx.fs:getInfo(dest) or ctx.fs:getInfo(dest).size == 0 then
				ctx.downloader:download(ffmpeg.url, dest)
			end
			ctx.fs:createDirectory(extract_to)
			if ffmpeg.archive:match("%.tar%.xz$") then
				ctx.shell:execute(string.format("tar -xf %q -C %q --strip-components=1", dest, extract_to))
			else
				local tmp = extract_to .. "-tmp"
				ctx.fs:createDirectory(tmp)
				ctx.shell:execute(string.format("unzip -o %q -d %q", dest, tmp))
				ctx.shell:execute(string.format("cp -r %s/*/* %s/", tmp, extract_to))
				ctx.fs:remove(tmp)
			end
		end
		if target == "linux" then
			ctx.shell:execute(string.format("find %s/lib -maxdepth 1 -name \"*.so.[0-9]*\" ! -name \"*.so.[0-9]*.*[0-9]*\" -exec cp -L {} %s \\;", extract_to, platform_bin))
			ctx.shell:execute(string.format("find %s/lib -maxdepth 1 -name \"*.so\" -exec cp -L {} %s \\;", extract_to, platform_bin))
		elseif target == "windows" then
			ctx.shell:execute(string.format("cp -r %s/bin/*.dll %s/", extract_to, platform_bin))
		end
	end

	-- 2. Process generic ZIP dependencies (BASS, FFTW, SQLite, Discord RPC)
	local generic_deps = {"bass", "bassmix", "bass_fx", "bassopus", "discord_rpc"}
	for _, dep_name in ipairs(generic_deps) do
		local config = deps[dep_name] and deps[dep_name][target]
		if config then
			local dest = "build/downloads/" .. config.archive
			local extract_to = "build/deps/" .. dep_name .. "_" .. target
			local have_extract = ctx.fs:getInfo(extract_to)
			local info = ctx.fs:getInfo(dest)
			-- Check if file is suspiciously small (e.g. less than 1KB)
			if info and info.size < 1024 and not have_extract then
				print("Removing corrupted dependency archive: " .. dest)
				ctx.fs:remove(dest)
				info = nil
			end
			
			if not have_extract then
				if not info or info.size == 0 then
					ctx.downloader:download(config.url, dest)
				end
				ctx.fs:createDirectory(extract_to)
				ctx.shell:execute(string.format("unzip -o %q -d %q", dest, extract_to))
			end
			
			-- Move binaries to bin/
			local ext = target == "windows" and "dll" or (target == "macos" and "dylib" or "so")
			if dep_name:match("^bass") then
				-- BASS has specific folder structures sometimes
				local pattern = target == "windows" and (target == "win64" and "x64/*.dll" or "*.dll") or (target == "linux" and "libs/x86_64/*.so" or "*.dylib")
				if target == "windows" then
					-- un4seen win zips usually have x64/ subfolder
					ctx.shell:execute(string.format("cp %s/x64/*.dll %s/ 2>/dev/null || cp %s/*.dll %s/ 2>/dev/null", extract_to, platform_bin, extract_to, platform_bin))
				elseif target == "linux" then
					ctx.shell:execute(string.format("cp %s/libs/x86_64/*.so %s/ 2>/dev/null || cp %s/*.so %s/ 2>/dev/null", extract_to, platform_bin, extract_to, platform_bin))
				else
					ctx.shell:execute(string.format("find %s -name \"*.dylib\" -exec cp {} %s/ \\;", extract_to, platform_bin))
				end
			else
				ctx.shell:execute(string.format("find %s -name \"*.%s*\" -exec cp {} %s/ \\;", extract_to, ext, platform_bin))
			end
		end
	end

	-- 3. Process Git dependencies (Minacalc, Luamidi)
	local git_deps = {"minacalc", "luamidi"}
	for _, dep_name in ipairs(git_deps) do
		local config = deps[dep_name]
		local dep_dir = "build/deps/" .. dep_name
		if not ctx.fs:getInfo(dep_dir) then
			print("Cloning " .. dep_name .. "...")
			ctx.shell:execute(string.format("git clone %s %s", config.url, dep_dir))
		end
		if dep_name == "luamidi" and not ctx.fs:getInfo(dep_dir .. "/rtmidi/RtMidi.h") then
			print("Initializing luamidi submodules...")
			ctx.shell:execute(string.format("git -C %s submodule update --init --recursive", dep_dir))
		end
	end

	-- 4. Fetch explicit prebuilt runtime binaries
	local prebuilt = deps.prebuilt_bins and deps.prebuilt_bins[target] or {}
	for _, item in ipairs(prebuilt) do
		local dest = "build/downloads/prebuilt/" .. target .. "/" .. item.name
		local bin_path = platform_bin .. "/" .. item.name
		local local_path = item.local_path
		local has_local = local_path and ctx.fs:getInfo(local_path)
		local has_dest = ctx.fs:getInfo(dest) and ctx.fs:getInfo(dest).size > 0
		local has_bin = ctx.fs:getInfo(bin_path)

		if has_local then
			ctx.shell:execute(string.format("cp -f %q %q", local_path, bin_path))
			if not has_dest then
				ctx.shell:execute(string.format("cp -f %q %q", local_path, dest))
			end
			goto continue_prebuilt
		end

		if has_dest then
			ctx.shell:execute(string.format("cp -f %q %q", dest, bin_path))
			goto continue_prebuilt
		end

		if has_bin then
			-- Keep existing repo-provided binary if present.
			goto continue_prebuilt
		end

		if item.url then
			ctx.downloader:download(item.url, dest)
			ctx.shell:execute(string.format("cp -f %q %q", dest, bin_path))
		else
			error("Prebuilt dependency is missing and has no download URL: " .. item.name)
		end
		::continue_prebuilt::
	end

	-- 5. Build Linux source dependencies (zlib, iconv, openssl, luasec, sqlite, fftw)
	if target == "linux" then
		local prefix = "build/deps/local/linux"
		local prefix_abs = root_abs .. "/" .. prefix
		ctx.fs:createDirectory("build/deps/local")
		ctx.fs:createDirectory(prefix)

		local zlib = deps.zlib_source and deps.zlib_source.linux
		if zlib then
			local extract_to = ensure_source_dep(zlib)
			if not ctx.fs:getInfo(prefix .. "/lib/libz.so") then
				ctx.shell:execute(string.format("bash -lc 'cd %q && ./configure --prefix=%q'", extract_to, prefix_abs))
				ctx.shell:execute(string.format("bash -lc 'cd %q && make -j$(nproc)'", extract_to))
				ctx.shell:execute(string.format("bash -lc 'cd %q && make install'", extract_to))
			end
			ctx.shell:execute(string.format("cp -L %q %q", prefix .. "/lib/libz.so", platform_bin .. "/libz.so"))
			if ctx.fs:getInfo(prefix .. "/lib/libz.so.1") then
				ctx.shell:execute(string.format("cp -L %q %q", prefix .. "/lib/libz.so.1", platform_bin .. "/libz.so.1"))
			end
		end

		local iconv = deps.iconv_source and deps.iconv_source.linux
		if iconv then
			local extract_to = ensure_source_dep(iconv)
			if not ctx.fs:getInfo(prefix .. "/lib/libiconv.so") or not ctx.fs:getInfo(prefix .. "/lib/libcharset.so") then
				ctx.shell:execute(string.format("bash -lc 'cd %q && ./configure --prefix=%q --enable-shared --disable-static CFLAGS=\"-fPIC\"'", extract_to, prefix_abs))
				ctx.shell:execute(string.format("bash -lc 'cd %q && make -j$(nproc)'", extract_to))
				ctx.shell:execute(string.format("bash -lc 'cd %q && make install'", extract_to))
			end
			ctx.shell:execute(string.format("cp -L %q %q", prefix .. "/lib/libiconv.so", platform_bin .. "/libiconv.so"))
			ctx.shell:execute(string.format("cp -L %q %q", prefix .. "/lib/libcharset.so", platform_bin .. "/libcharset.so"))
		end

		local openssl = deps.openssl_source and deps.openssl_source.linux
		if openssl then
			local extract_to = ensure_source_dep(openssl)
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
			ctx.shell:execute(string.format("cp -L %q %q", openssl_lib_dir .. "/libssl.so", platform_bin .. "/libssl.so"))
			ctx.shell:execute(string.format("cp -L %q %q", openssl_lib_dir .. "/libcrypto.so", platform_bin .. "/libcrypto.so"))
			if ctx.fs:getInfo(openssl_lib_dir .. "/libssl.so.3") then
				ctx.shell:execute(string.format("cp -L %q %q", openssl_lib_dir .. "/libssl.so.3", platform_bin .. "/libssl.so.3"))
			end
			if ctx.fs:getInfo(openssl_lib_dir .. "/libcrypto.so.3") then
				ctx.shell:execute(string.format("cp -L %q %q", openssl_lib_dir .. "/libcrypto.so.3", platform_bin .. "/libcrypto.so.3"))
			end
		end

		local luasec = deps.luasec_source and deps.luasec_source.linux
		if luasec then
			local extract_to = ensure_source_dep(luasec)
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
			local extract_to = ensure_source_dep(sqlite)
			ctx.shell:execute(string.format(
				"gcc -shared -fPIC -O2 %q -o %q -lm -ldl -lpthread",
				extract_to .. "/sqlite3.c",
				platform_bin .. "/libsqlite3.so"
			))
		end

		local fftw = deps.fftw_source and deps.fftw_source.linux
		if fftw then
			local extract_to = ensure_source_dep(fftw)
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

	-- 6. Handle 7z SDK
	local s7 = deps.sevenzip
	local s7_dest = "build/downloads/" .. s7.archive
	local s7_extract = "build/deps/" .. s7.dir
	if not ctx.fs:getInfo(s7_dest) then
		ctx.downloader:download(s7.url, s7_dest)
	end
	ctx.fs:createDirectory(s7_extract)
	ctx.shell:execute(string.format("7z x -y %q -o%q", s7_dest, s7_extract))

	-- 7. Handle love binaries for packaging
	local love_win = deps.love_win
	if love_win then
		local dest = "build/downloads/" .. love_win.archive
		if not ctx.fs:getInfo(dest) then
			ctx.downloader:download(love_win.url, dest)
		end
		local extract_to = "build/deps/love_win"
		ctx.fs:createDirectory(extract_to)
		ctx.shell:execute(string.format("unzip -o %q -d %q", dest, extract_to))
		-- Copy to bin/win64
		ctx.shell:execute(string.format("cp -r %s/*/* %s/", extract_to, platform_bin_map.windows))
	end

	local love_linux = deps.love_linux
	if love_linux then
		local dest = "build/downloads/" .. love_linux.archive
		if not ctx.fs:getInfo(dest) then
			ctx.downloader:download(love_linux.url, dest)
		end
		ctx.shell:execute(string.format("cp %s %s/", dest, platform_bin_map.linux))
		ctx.shell:execute(string.format("chmod +x %s/%s", platform_bin_map.linux, love_linux.archive))
	end

	-- 8. Handle love-macos
	local love_macos = deps.love_macos
	if love_macos then
		local dest = "build/downloads/" .. love_macos.archive
		if not ctx.fs:getInfo(dest) then
			ctx.downloader:download(love_macos.url, dest)
		end
	end
end

function FetchDeps:upToDate(ctx)
	local target = self.target:lower()
	local check_dirs = {"7zsdk", "minacalc", "luamidi"}
	for _, d in ipairs(check_dirs) do
		if not ctx.fs:getInfo("build/deps/" .. d) then return false end
	end
	if not ctx.fs:getInfo("build/deps/luamidi/rtmidi/RtMidi.h") then return false end

	if target == "linux" then
		if deps.zlib_source and deps.zlib_source.linux then
			if not ctx.fs:getInfo("build/deps/" .. deps.zlib_source.linux.dir) then return false end
			if not ctx.fs:getInfo("bin/linux64/libz.so") then return false end
		end
		if deps.iconv_source and deps.iconv_source.linux then
			if not ctx.fs:getInfo("build/deps/" .. deps.iconv_source.linux.dir) then return false end
			if not ctx.fs:getInfo("bin/linux64/libiconv.so") then return false end
			if not ctx.fs:getInfo("bin/linux64/libcharset.so") then return false end
		end
		if deps.openssl_source and deps.openssl_source.linux then
			if not ctx.fs:getInfo("build/deps/" .. deps.openssl_source.linux.dir) then return false end
			if not ctx.fs:getInfo("bin/linux64/libssl.so") then return false end
			if not ctx.fs:getInfo("bin/linux64/libcrypto.so") then return false end
		end
		if deps.luasec_source and deps.luasec_source.linux then
			if not ctx.fs:getInfo("build/deps/" .. deps.luasec_source.linux.dir) then return false end
			if not ctx.fs:getInfo("bin/linux64/ssl.so") then return false end
		end
		if deps.sqlite_source and deps.sqlite_source.linux then
			if not ctx.fs:getInfo("build/deps/" .. deps.sqlite_source.linux.dir) then return false end
			if not ctx.fs:getInfo("bin/linux64/libsqlite3.so") then return false end
		end
		if deps.fftw_source and deps.fftw_source.linux then
			if not ctx.fs:getInfo("build/deps/" .. deps.fftw_source.linux.dir) then return false end
			if not ctx.fs:getInfo("bin/linux64/libfftw3.so") then return false end
		end
	end

	local prebuilt = deps.prebuilt_bins and deps.prebuilt_bins[target] or {}
	for _, item in ipairs(prebuilt) do
		if not ctx.fs:getInfo("bin/" .. (target == "windows" and "win64" or (target == "macos" and "mac64" or "linux64")) .. "/" .. item.name) then
			return false
		end
	end
	
	local generic_deps = {"bass", "bassmix", "bass_fx", "bassopus", "discord_rpc"}
	for _, d in ipairs(generic_deps) do
		if deps[d] and deps[d][target] then
			if not ctx.fs:getInfo("build/deps/" .. d .. "_" .. target) then return false end
		end
	end

	if deps.love_win and not ctx.fs:getInfo("build/deps/love_win") then return false end
	-- love_linux is just a file in bin
	if deps.love_linux and not ctx.fs:getInfo("bin/linux64/" .. deps.love_linux.archive) then return false end

	-- Check ffmpeg
	local ffmpeg = deps.ffmpeg[target]
	if ffmpeg and not ctx.fs:getInfo("build/deps/" .. ffmpeg.dir) then
		return false
	end

	if deps.love_macos and not ctx.fs:getInfo("build/downloads/" .. deps.love_macos.archive) then
		return false
	end
	return true
end

function FetchDeps:getStatus(ctx)
	local target = self.target:lower()
	local res = {}
	
	local function check_dep(name, download_path, extract_path)
		local dl = ctx.fs:getInfo(download_path) and "OK" or "MISSING"
		local ex = ctx.fs:getInfo(extract_path) and "OK" or "MISSING"
		if dl == "MISSING" and ex == "OK" then
			dl = "CACHED"
		end
		table.insert(res, { name = name, value = string.format("DL: [%s] EX: [%s]", dl, ex) })
	end

	local ffmpeg = deps.ffmpeg[target]
	if ffmpeg then
		check_dep("FFmpeg (" .. target .. ")", "build/downloads/" .. ffmpeg.archive, "build/deps/" .. ffmpeg.dir)
	end

	if target == "linux" then
		local zlib = deps.zlib_source and deps.zlib_source.linux
		if zlib then
			check_dep("ZLIB (linux-src)", "build/downloads/" .. zlib.archive, "build/deps/" .. zlib.dir)
			table.insert(res, { name = "ZLIB lib (linux)", value = ctx.fs:getInfo("bin/linux64/libz.so") and "OK" or "MISSING" })
		end
		local iconv = deps.iconv_source and deps.iconv_source.linux
		if iconv then
			check_dep("ICONV (linux-src)", "build/downloads/" .. iconv.archive, "build/deps/" .. iconv.dir)
			table.insert(res, { name = "ICONV libs (linux)", value = (ctx.fs:getInfo("bin/linux64/libiconv.so") and ctx.fs:getInfo("bin/linux64/libcharset.so")) and "OK" or "MISSING" })
		end
		local openssl = deps.openssl_source and deps.openssl_source.linux
		if openssl then
			check_dep("OPENSSL (linux-src)", "build/downloads/" .. openssl.archive, "build/deps/" .. openssl.dir)
			table.insert(res, { name = "OPENSSL libs (linux)", value = (ctx.fs:getInfo("bin/linux64/libssl.so") and ctx.fs:getInfo("bin/linux64/libcrypto.so")) and "OK" or "MISSING" })
		end
		local luasec = deps.luasec_source and deps.luasec_source.linux
		if luasec then
			check_dep("LUASEC (linux-src)", "build/downloads/" .. luasec.archive, "build/deps/" .. luasec.dir)
			table.insert(res, { name = "LUASEC module (linux)", value = ctx.fs:getInfo("bin/linux64/ssl.so") and "OK" or "MISSING" })
		end
		local sqlite = deps.sqlite_source and deps.sqlite_source.linux
		if sqlite then
			check_dep("SQLITE (linux-src)", "build/downloads/" .. sqlite.archive, "build/deps/" .. sqlite.dir)
			table.insert(res, { name = "SQLITE lib (linux)", value = ctx.fs:getInfo("bin/linux64/libsqlite3.so") and "OK" or "MISSING" })
		end
		local fftw = deps.fftw_source and deps.fftw_source.linux
		if fftw then
			check_dep("FFTW (linux-src)", "build/downloads/" .. fftw.archive, "build/deps/" .. fftw.dir)
			table.insert(res, { name = "FFTW lib (linux)", value = ctx.fs:getInfo("bin/linux64/libfftw3.so") and "OK" or "MISSING" })
		end
	end

	local prebuilt = deps.prebuilt_bins and deps.prebuilt_bins[target] or {}
	for _, item in ipairs(prebuilt) do
		local dl_path = "build/downloads/prebuilt/" .. target .. "/" .. item.name
		local bin_dir = target == "windows" and "bin/win64" or (target == "macos" and "bin/mac64" or "bin/linux64")
		local bin_path = bin_dir .. "/" .. item.name
		local dl = ctx.fs:getInfo(dl_path) and "OK" or "MISSING"
		if item.local_path and ctx.fs:getInfo(item.local_path) then
			dl = "LOCAL"
		end
		local bn = ctx.fs:getInfo(bin_path) and "OK" or "MISSING"
		if dl == "MISSING" and bn == "OK" then
			dl = "CACHED"
		end
		table.insert(res, { name = "PREBUILT " .. item.name .. " (" .. target .. ")", value = string.format("DL: [%s] BIN: [%s]", dl, bn) })
	end
	
	local generic_deps = {"bass", "discord_rpc"}
	for _, d in ipairs(generic_deps) do
		local config = deps[d] and deps[d][target]
		if config then
			check_dep(d:upper() .. " (" .. target .. ")", "build/downloads/" .. config.archive, "build/deps/" .. d .. "_" .. target)
		end
	end

	local s7 = deps.sevenzip
	check_dep("7z SDK", "build/downloads/" .. s7.archive, "build/deps/" .. s7.dir)

	local git_deps = {"minacalc", "luamidi"}
	for _, d in ipairs(git_deps) do
		local exists = ctx.fs:getInfo("build/deps/" .. d) and "OK" or "MISSING"
		table.insert(res, { name = d:upper() .. " (git)", value = exists })
	end

	if deps.love_macos then
		local dl = ctx.fs:getInfo("build/downloads/" .. deps.love_macos.archive) and "OK" or "MISSING"
		table.insert(res, { name = "macOS Love Zip", value = dl })
	end
	
	return res
end

return FetchDeps
