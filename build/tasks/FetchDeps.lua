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
	local config = deps.ffmpeg[target]
	
	ctx.fs:createDirectory("build/downloads")
	ctx.fs:createDirectory("build/deps")
	
	if config then
		local dest = "build/downloads/" .. config.archive
		local extract_to = "build/deps/" .. config.dir
		
		local info = ctx.fs:getInfo(dest)
		if not info or info.size == 0 then
			ctx.downloader:download(config.url, dest)
		end
		
		ctx.fs:createDirectory(extract_to)
		if config.archive:match("%.tar%.xz$") then
			ctx.shell:execute(string.format("tar -xf %q -C %q --strip-components=1", dest, extract_to))
		else
			local tmp = extract_to .. "-tmp"
			ctx.fs:createDirectory(tmp)
			ctx.shell:execute(string.format("unzip -o %q -d %q", dest, tmp))
			ctx.shell:execute(string.format("cp -r %s/*/* %s/", tmp, extract_to))
			ctx.fs:remove(tmp)
		end
		
		-- Copy binaries to bin/
		local platform_bin = "bin/" .. (target == "linux" and "linux64" or "win64")
		ctx.fs:createDirectory(platform_bin)
		if target == "linux" then
			ctx.shell:execute(string.format("find %s/lib -maxdepth 1 -name \"*.so.[0-9]*\" ! -name \"*.so.[0-9]*.*[0-9]*\" -exec cp -L {} %s \\;", extract_to, platform_bin))
			ctx.shell:execute(string.format("find %s/lib -maxdepth 1 -name \"*.so\" -exec cp -L {} %s \\;", extract_to, platform_bin))
		else
			ctx.shell:execute(string.format("cp -r %s/bin/*.dll %s/", extract_to, platform_bin))
		end
	end
	
	-- Handle 7z SDK
	local s7 = deps.sevenzip
	local s7_dest = "build/downloads/" .. s7.archive
	local s7_extract = "build/deps/" .. s7.dir
	if not ctx.fs:getInfo(s7_dest) then
		ctx.downloader:download(s7.url, s7_dest)
	end
	ctx.fs:createDirectory(s7_extract)
	ctx.shell:execute(string.format("7z x -y %q -o%q", s7_dest, s7_extract))

	-- Handle love-macos
	local love_macos = deps.love_macos
	if love_macos then
		local dest = "build/downloads/" .. love_macos.archive
		if not ctx.fs:getInfo(dest) then
			ctx.downloader:download(love_macos.url, dest)
		end
	end
end

function FetchDeps:upToDate(ctx)
	-- Simple check: if extracted folders exist, we assume it's fine for now
	local target = self.target:lower()
	local config = deps.ffmpeg[target]
	if config and not ctx.fs:getInfo("build/deps/" .. config.dir) then
		return false
	end
	if not ctx.fs:getInfo("build/deps/" .. deps.sevenzip.dir) then
		return false
	end
	if deps.love_macos and not ctx.fs:getInfo("build/downloads/" .. deps.love_macos.archive) then
		return false
	end
	return true
end

function FetchDeps:getStatus(ctx)
	local target = self.target:lower()
	local config = deps.ffmpeg[target]
	local res = {}
	
	if config then
		local dl = ctx.fs:getInfo("build/downloads/" .. config.archive) and "OK" or "MISSING"
		local ex = ctx.fs:getInfo("build/deps/" .. config.dir) and "OK" or "MISSING"
		table.insert(res, { name = "FFmpeg (" .. target .. ")", value = string.format("DL: [%s] EX: [%s]", dl, ex) })
	end
	
	local s7 = deps.sevenzip
	local s7_dl = ctx.fs:getInfo("build/downloads/" .. s7.archive) and "OK" or "MISSING"
	local s7_ex = ctx.fs:getInfo("build/deps/" .. s7.dir) and "OK" or "MISSING"
	table.insert(res, { name = "7z SDK", value = string.format("DL: [%s] EX: [%s]", s7_dl, s7_ex) })

	if deps.love_macos then
		local dl = ctx.fs:getInfo("build/downloads/" .. deps.love_macos.archive) and "OK" or "MISSING"
		table.insert(res, { name = "macOS Love Zip", value = dl })
	end
	
	return res
end

return FetchDeps
