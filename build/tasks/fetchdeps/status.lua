local BuildConfig = require("build.BuildConfig")

local Status = {}

local function check_dep(ctx, res, name, download_path, extract_path)
	local dl = ctx.fs:getInfo(download_path) and "OK" or "MISSING"
	local ex = ctx.fs:getInfo(extract_path) and "OK" or "MISSING"
	if dl == "MISSING" and ex == "OK" then
		dl = "CACHED"
	end
	table.insert(res, { name = name, value = string.format("DL: [%s] EX: [%s]", dl, ex) })
end

function Status.upToDate(env)
	local ctx = env.ctx
	local deps = env.deps
	local target = env.target
	local check_dirs = {"7zsdk", "minacalc", "luamidi"}
	for _, d in ipairs(check_dirs) do
		if not ctx.fs:getInfo("build/deps/" .. d) then
			return false
		end
	end
	if not ctx.fs:getInfo("build/deps/luamidi/rtmidi/RtMidi.h") then
		return false
	end

	if target == "linux" then
		if deps.zlib_source and deps.zlib_source.linux then
			if not ctx.fs:getInfo("build/deps/" .. deps.zlib_source.linux.dir) then return false end
			if not ctx.fs:getInfo("bin/linux64/libz.so.1") then return false end
		end
		if deps.iconv_source and deps.iconv_source.linux then
			if not ctx.fs:getInfo("build/deps/" .. deps.iconv_source.linux.dir) then return false end
			if not ctx.fs:getInfo("bin/linux64/libiconv.so") then return false end
			if not ctx.fs:getInfo("bin/linux64/libcharset.so") then return false end
		end
		if deps.openssl_source and deps.openssl_source.linux then
			if not ctx.fs:getInfo("build/deps/" .. deps.openssl_source.linux.dir) then return false end
			if not ctx.fs:getInfo("bin/linux64/libssl.so.3") then return false end
			if not ctx.fs:getInfo("bin/linux64/libcrypto.so.3") then return false end
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
	elseif target == "windows" then
		if deps.zlib_source and deps.zlib_source.windows then
			if not ctx.fs:getInfo("build/deps/" .. deps.zlib_source.windows.dir) then return false end
			if not ctx.fs:getInfo("bin/win64/z.dll") then return false end
		end
		if deps.iconv_source and deps.iconv_source.windows then
			if not ctx.fs:getInfo("build/deps/" .. deps.iconv_source.windows.dir) then return false end
			if not ctx.fs:getInfo("bin/win64/libiconv-2.dll") then return false end
		end
		if deps.openssl_source and deps.openssl_source.windows then
			if not ctx.fs:getInfo("build/deps/" .. deps.openssl_source.windows.dir) then return false end
			if not ctx.fs:getInfo("bin/win64/libssl-3-x64.dll") then return false end
			if not ctx.fs:getInfo("bin/win64/libcrypto-3-x64.dll") then return false end
		end
		if deps.luasec_source and deps.luasec_source.windows then
			if not ctx.fs:getInfo("build/deps/" .. deps.luasec_source.windows.dir) then return false end
			if not ctx.fs:getInfo("bin/win64/ssl.dll") then return false end
		end
	elseif target == "macos" then
		if deps.ffmpeg_source and deps.ffmpeg_source.macos then
			if not ctx.fs:getInfo("build/deps/" .. deps.ffmpeg_source.macos.dir) then return false end
			if not ctx.fs:getInfo("bin/mac64/libavcodec.dylib") then return false end
			if not ctx.fs:getInfo("bin/mac64/libavformat.dylib") then return false end
			if not ctx.fs:getInfo("bin/mac64/libavutil.dylib") then return false end
			if not ctx.fs:getInfo("bin/mac64/libswscale.dylib") then return false end
			if not ctx.fs:getInfo("bin/mac64/libswresample.dylib") then return false end
		end
		if deps.zlib_source and deps.zlib_source.macos then
			if not ctx.fs:getInfo("build/deps/" .. deps.zlib_source.macos.dir) then return false end
			if not ctx.fs:getInfo("bin/mac64/libz.dylib") then return false end
		end
		if deps.iconv_source and deps.iconv_source.macos then
			if not ctx.fs:getInfo("build/deps/" .. deps.iconv_source.macos.dir) then return false end
			if not ctx.fs:getInfo("bin/mac64/libiconv.dylib") then return false end
			if not ctx.fs:getInfo("bin/mac64/libcharset.dylib") then return false end
		end
		if deps.openssl_source and deps.openssl_source.macos then
			if not ctx.fs:getInfo("build/deps/" .. deps.openssl_source.macos.dir) then return false end
			if not ctx.fs:getInfo("bin/mac64/libssl.dylib") then return false end
			if not ctx.fs:getInfo("bin/mac64/libcrypto.dylib") then return false end
		end
		if deps.luasec_source and deps.luasec_source.macos then
			if not ctx.fs:getInfo("build/deps/" .. deps.luasec_source.macos.dir) then return false end
			if not ctx.fs:getInfo("bin/mac64/ssl.dylib") then return false end
		end
	end

	local prebuilt = deps.prebuilt_bins and deps.prebuilt_bins[target] or {}
	local bin_dir = BuildConfig.getBinDir(target)
	for _, item in ipairs(prebuilt) do
		if not ctx.fs:getInfo(bin_dir .. "/" .. item.name) then
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
	if deps.love_linux and not ctx.fs:getInfo("bin/linux64/" .. deps.love_linux.archive) then return false end

	local ffmpeg = deps.ffmpeg[target]
	if ffmpeg and not ctx.fs:getInfo("build/deps/" .. ffmpeg.dir) then
		return false
	end

	if deps.love_macos and not ctx.fs:getInfo("build/downloads/" .. deps.love_macos.archive) then
		return false
	end

	return true
end

function Status.getStatus(env)
	local ctx = env.ctx
	local deps = env.deps
	local target = env.target
	local res = {}

	local ffmpeg = deps.ffmpeg[target]
	if ffmpeg then
		check_dep(ctx, res, "FFmpeg (" .. target .. ")", "build/downloads/" .. ffmpeg.archive, "build/deps/" .. ffmpeg.dir)
	end

	if target == "linux" then
		local zlib = deps.zlib_source and deps.zlib_source.linux
		if zlib then
			check_dep(ctx, res, "ZLIB (linux-src)", "build/downloads/" .. zlib.archive, "build/deps/" .. zlib.dir)
			table.insert(res, { name = "ZLIB lib (linux)", value = ctx.fs:getInfo("bin/linux64/libz.so.1") and "OK" or "MISSING" })
		end
		local iconv = deps.iconv_source and deps.iconv_source.linux
		if iconv then
			check_dep(ctx, res, "ICONV (linux-src)", "build/downloads/" .. iconv.archive, "build/deps/" .. iconv.dir)
			table.insert(res, { name = "ICONV libs (linux)", value = (ctx.fs:getInfo("bin/linux64/libiconv.so") and ctx.fs:getInfo("bin/linux64/libcharset.so")) and "OK" or "MISSING" })
		end
		local openssl = deps.openssl_source and deps.openssl_source.linux
		if openssl then
			check_dep(ctx, res, "OPENSSL (linux-src)", "build/downloads/" .. openssl.archive, "build/deps/" .. openssl.dir)
			table.insert(res, { name = "OPENSSL libs (linux)", value = (ctx.fs:getInfo("bin/linux64/libssl.so.3") and ctx.fs:getInfo("bin/linux64/libcrypto.so.3")) and "OK" or "MISSING" })
		end
		local luasec = deps.luasec_source and deps.luasec_source.linux
		if luasec then
			check_dep(ctx, res, "LUASEC (linux-src)", "build/downloads/" .. luasec.archive, "build/deps/" .. luasec.dir)
			table.insert(res, { name = "LUASEC module (linux)", value = ctx.fs:getInfo("bin/linux64/ssl.so") and "OK" or "MISSING" })
		end
		local sqlite = deps.sqlite_source and deps.sqlite_source.linux
		if sqlite then
			check_dep(ctx, res, "SQLITE (linux-src)", "build/downloads/" .. sqlite.archive, "build/deps/" .. sqlite.dir)
			table.insert(res, { name = "SQLITE lib (linux)", value = ctx.fs:getInfo("bin/linux64/libsqlite3.so") and "OK" or "MISSING" })
		end
		local fftw = deps.fftw_source and deps.fftw_source.linux
		if fftw then
			check_dep(ctx, res, "FFTW (linux-src)", "build/downloads/" .. fftw.archive, "build/deps/" .. fftw.dir)
			table.insert(res, { name = "FFTW lib (linux)", value = ctx.fs:getInfo("bin/linux64/libfftw3.so") and "OK" or "MISSING" })
		end
	elseif target == "windows" then
		local zlib = deps.zlib_source and deps.zlib_source.windows
		if zlib then
			check_dep(ctx, res, "ZLIB (windows-src)", "build/downloads/" .. zlib.archive, "build/deps/" .. zlib.dir)
			table.insert(res, { name = "ZLIB lib (windows)", value = ctx.fs:getInfo("bin/win64/z.dll") and "OK" or "MISSING" })
		end
		local iconv = deps.iconv_source and deps.iconv_source.windows
		if iconv then
			check_dep(ctx, res, "ICONV (windows-src)", "build/downloads/" .. iconv.archive, "build/deps/" .. iconv.dir)
			table.insert(res, { name = "ICONV lib (windows)", value = ctx.fs:getInfo("bin/win64/libiconv-2.dll") and "OK" or "MISSING" })
		end
		local openssl = deps.openssl_source and deps.openssl_source.windows
		if openssl then
			check_dep(ctx, res, "OPENSSL (windows-src)", "build/downloads/" .. openssl.archive, "build/deps/" .. openssl.dir)
			table.insert(res, { name = "OPENSSL libs (windows)", value = (ctx.fs:getInfo("bin/win64/libssl-3-x64.dll") and ctx.fs:getInfo("bin/win64/libcrypto-3-x64.dll")) and "OK" or "MISSING" })
		end
		local luasec = deps.luasec_source and deps.luasec_source.windows
		if luasec then
			check_dep(ctx, res, "LUASEC (windows-src)", "build/downloads/" .. luasec.archive, "build/deps/" .. luasec.dir)
			table.insert(res, { name = "LUASEC module (windows)", value = ctx.fs:getInfo("bin/win64/ssl.dll") and "OK" or "MISSING" })
		end
	elseif target == "macos" then
		local ffmpeg_src = deps.ffmpeg_source and deps.ffmpeg_source.macos
		if ffmpeg_src then
			check_dep(ctx, res, "FFMPEG (macos-src)", "build/downloads/" .. ffmpeg_src.archive, "build/deps/" .. ffmpeg_src.dir)
			table.insert(res, {
				name = "FFMPEG libs (macos)",
				value = (ctx.fs:getInfo("bin/mac64/libavcodec.dylib")
					and ctx.fs:getInfo("bin/mac64/libavformat.dylib")
					and ctx.fs:getInfo("bin/mac64/libavutil.dylib")
					and ctx.fs:getInfo("bin/mac64/libswscale.dylib")
					and ctx.fs:getInfo("bin/mac64/libswresample.dylib"))
					and "OK" or "MISSING",
			})
		end
		local zlib = deps.zlib_source and deps.zlib_source.macos
		if zlib then
			check_dep(ctx, res, "ZLIB (macos-src)", "build/downloads/" .. zlib.archive, "build/deps/" .. zlib.dir)
			table.insert(res, { name = "ZLIB lib (macos)", value = ctx.fs:getInfo("bin/mac64/libz.dylib") and "OK" or "MISSING" })
		end
		local iconv = deps.iconv_source and deps.iconv_source.macos
		if iconv then
			check_dep(ctx, res, "ICONV (macos-src)", "build/downloads/" .. iconv.archive, "build/deps/" .. iconv.dir)
			table.insert(res, { name = "ICONV libs (macos)", value = (ctx.fs:getInfo("bin/mac64/libiconv.dylib") and ctx.fs:getInfo("bin/mac64/libcharset.dylib")) and "OK" or "MISSING" })
		end
		local openssl = deps.openssl_source and deps.openssl_source.macos
		if openssl then
			check_dep(ctx, res, "OPENSSL (macos-src)", "build/downloads/" .. openssl.archive, "build/deps/" .. openssl.dir)
			table.insert(res, { name = "OPENSSL libs (macos)", value = (ctx.fs:getInfo("bin/mac64/libssl.dylib") and ctx.fs:getInfo("bin/mac64/libcrypto.dylib")) and "OK" or "MISSING" })
		end
		local luasec = deps.luasec_source and deps.luasec_source.macos
		if luasec then
			check_dep(ctx, res, "LUASEC (macos-src)", "build/downloads/" .. luasec.archive, "build/deps/" .. luasec.dir)
			table.insert(res, { name = "LUASEC module (macos)", value = ctx.fs:getInfo("bin/mac64/ssl.dylib") and "OK" or "MISSING" })
		end
	end

	local prebuilt = deps.prebuilt_bins and deps.prebuilt_bins[target] or {}
	for _, item in ipairs(prebuilt) do
		local dl_path = "build/downloads/prebuilt/" .. target .. "/" .. item.name
		local bin_dir = BuildConfig.getBinDir(target)
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
			check_dep(ctx, res, d:upper() .. " (" .. target .. ")", "build/downloads/" .. config.archive, "build/deps/" .. d .. "_" .. target)
		end
	end

	local s7 = deps.sevenzip
	check_dep(ctx, res, "7z SDK", "build/downloads/" .. s7.archive, "build/deps/" .. s7.dir)

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

return Status
