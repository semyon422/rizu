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
	ctx.fs:createDirectory("build/downloads")
	ctx.fs:createDirectory("build/deps")

	local platform_bin_map = {
		linux   = "bin/linux64",
		windows = "bin/win64",
		macos   = "bin/mac64",
	}
	local platform_bin = platform_bin_map[target] or platform_bin_map.linux
	ctx.fs:createDirectory(platform_bin)

	-- 1. Process FFmpeg
	local ffmpeg = deps.ffmpeg[target]
	if ffmpeg then
		local dest = "build/downloads/" .. ffmpeg.archive
		local extract_to = "build/deps/" .. ffmpeg.dir
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
		if target == "linux" then
			ctx.shell:execute(string.format("find %s/lib -maxdepth 1 -name \"*.so.[0-9]*\" ! -name \"*.so.[0-9]*.*[0-9]*\" -exec cp -L {} %s \\;", extract_to, platform_bin))
			ctx.shell:execute(string.format("find %s/lib -maxdepth 1 -name \"*.so\" -exec cp -L {} %s \\;", extract_to, platform_bin))
		elseif target == "windows" then
			ctx.shell:execute(string.format("cp -r %s/bin/*.dll %s/", extract_to, platform_bin))
		end
	end

	-- 2. Process generic ZIP dependencies (BASS, FFTW, SQLite, Discord RPC)
	local generic_deps = {"bass", "bassmix", "bass_fx", "bassopus", "fftw", "sqlite", "discord_rpc"}
	for _, dep_name in ipairs(generic_deps) do
		local config = deps[dep_name] and deps[dep_name][target]
		if config then
			local dest = "build/downloads/" .. config.archive
			local info = ctx.fs:getInfo(dest)
			-- Check if file is suspiciously small (e.g. less than 1KB)
			if info and info.size < 1024 then
				print("Removing corrupted dependency archive: " .. dest)
				ctx.fs:remove(dest)
				info = nil
			end
			
			if not info or info.size == 0 then
				ctx.downloader:download(config.url, dest)
			end
			local extract_to = "build/deps/" .. dep_name .. "_" .. target
			ctx.fs:createDirectory(extract_to)
			ctx.shell:execute(string.format("unzip -o %q -d %q", dest, extract_to))
			
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
					ctx.shell:execute(string.format("cp %s/*.dylib %s/ 2>/dev/null", extract_to, platform_bin))
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
	end

	-- 4. Handle 7z SDK
	local s7 = deps.sevenzip
	local s7_dest = "build/downloads/" .. s7.archive
	local s7_extract = "build/deps/" .. s7.dir
	if not ctx.fs:getInfo(s7_dest) then
		ctx.downloader:download(s7.url, s7_dest)
	end
	ctx.fs:createDirectory(s7_extract)
	ctx.shell:execute(string.format("7z x -y %q -o%q", s7_dest, s7_extract))

	-- 5. Handle love binaries for packaging
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

	-- 6. Handle love-macos
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
	
	local generic_deps = {"bass", "bassmix", "bass_fx", "bassopus", "fftw", "sqlite", "discord_rpc"}
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
		table.insert(res, { name = name, value = string.format("DL: [%s] EX: [%s]", dl, ex) })
	end

	local ffmpeg = deps.ffmpeg[target]
	if ffmpeg then
		check_dep("FFmpeg (" .. target .. ")", "build/downloads/" .. ffmpeg.archive, "build/deps/" .. ffmpeg.dir)
	end
	
	local generic_deps = {"bass", "fftw", "sqlite", "discord_rpc"}
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
