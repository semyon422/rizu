local class = require("class")
local BuildConfig = require("rizu.build.BuildConfig")

---@class rizu.build.Builder
---@operator call: rizu.build.Builder
---@field ctx rizu.build.Context
---@field target rizu.build.Target
local Builder = class()

---@param ctx rizu.build.Context
---@param target? rizu.build.Target
function Builder:new(ctx, target)
	self.ctx = ctx
	self.target = BuildConfig.normalizeTarget(target or ctx.target)
end

local function toCxx(cc)
	return cc:gsub("gcc", "g++"):gsub("clang", "clang++")
end

local function compilerAvailable(shell, cmd)
	local probe = string.format("bash -lc %q", cmd .. " --version >/dev/null 2>&1 && echo OK || echo MISSING")
	local out = shell:popen(probe)
	return out and out:match("OK")
end

function Builder:getCompiler()
	local t = self.target

	if jit.os == "Linux" then
		local compilers = {
			windows = "x86_64-w64-mingw32-gcc",
			macos = "x86_64-apple-darwin22.2-clang",
		}
		local cc = compilers[t] or "gcc"

		if t == "macos" then
			local osxcross_bin = self.ctx.shell:popen("pwd"):gsub("%s+$", "") .. "/build/deps/osxcross/target/bin"
			if self.ctx.fs:getInfo("build/deps/osxcross/target/bin/" .. cc) then
				return string.format("PATH=%s:$PATH %s/%s", osxcross_bin, osxcross_bin, cc)
			end
		end

		return cc
	end
	return "gcc"
end

function Builder:getFFmpegPaths()
	local t = self.target
	if t == "macos" then
		local inc = "build/deps/local/macos/ffmpeg/include"
		local lib = "bin/mac64"
		if self.ctx.fs:getInfo(inc .. "/libavcodec/avcodec.h") and self.ctx.fs:getInfo(lib .. "/libavcodec.dylib") then
			return inc, lib
		end
	end
	local suffix_map = {
		windows = "win",
		macos = "macos", -- potentially
	}
	local suffix = suffix_map[t] or "linux"
	local base = "build/deps/ffmpeg-" .. suffix

	local inc = base .. "/include"
	local lib = base .. "/lib"

	if not self.ctx.fs:getInfo(inc .. "/libavcodec/avcodec.h") then
		return nil, nil
	end

	return inc, lib
end

function Builder:get7zInc()
	local base = "build/deps/7zsdk/C"
	if self.ctx.fs:getInfo(base .. "/Alloc.c") then
		return base
	end
	return "aqua"
end

function Builder:getArtifactsDir()
	local dir = BuildConfig.getArtifactsDir(self.target)
	self.ctx.fs:createDirectory("build/artifacts")
	self.ctx.fs:createDirectory(dir)
	return dir
end

function Builder:getBinDir()
	local dir = BuildConfig.getBinDir(self.target)
	self.ctx.fs:createDirectory("bin")
	self.ctx.fs:createDirectory(dir)
	return dir
end

function Builder:getModuleOutputs()
	local out_dir = self:getArtifactsDir()
	return BuildConfig.getModuleOutputs(self.target, out_dir)
end

function Builder:build7z()
	local t = self.target
	local cc = self:getCompiler()
	local inc = "-I" .. self:get7zInc()
	local src = "aqua/7z.c"

	local out_map = {
		windows = self:getModuleOutputs().z7,
		macos = self:getModuleOutputs().z7,
		linux = self:getModuleOutputs().z7,
	}
	local flag_map = {
		linux = "-D_GNU_SOURCE -shared -fPIC",
	}

	local out = out_map[t] or out_map.linux
	local flags = flag_map[t] or "-shared -fPIC"

	self.ctx.shell:execute(string.format("%s %s %s -o %s %s", cc, inc, flags, out, src))
end

function Builder:buildVideo()
	local t = self.target
	local cc = self:getCompiler()
	local ffmpeg_inc, ffmpeg_lib_dir = self:getFFmpegPaths()
	if not ffmpeg_inc then
		print("FFmpeg headers not found for " .. t .. ", skipping video module build.")
		return
	end

	local luajit_inc = "tree/include/luajit-2.1"
	local src = "aqua/video.c"

	local out_map = {
		windows = self:getModuleOutputs().video,
		macos = self:getModuleOutputs().video,
		linux = self:getModuleOutputs().video,
	}
	local flag_map = {
		macos = "-shared -fPIC -undefined dynamic_lookup -Wl,-rpath,@loader_path",
		linux = "-shared -fPIC -Wl,-rpath,'$ORIGIN'",
	}

	local out = out_map[t] or out_map.linux
	local flags = flag_map[t] or "-shared -fPIC"

	local libs
	if t == "windows" then
		libs = string.format("-Ltree/lib -L%s -lavformat -lavcodec -lswresample -lswscale -lavutil -lm -l:libluajit-5.1.dll.a", ffmpeg_lib_dir)
	elseif t == "macos" then
		libs = string.format("-L%s -lavformat -lavcodec -lswresample -lswscale -lavutil -lm", ffmpeg_lib_dir)
	else
		libs = string.format("-L%s -lavformat -lavcodec -lswresample -lswscale -lavutil -lm", ffmpeg_lib_dir)
	end

	local inc = string.format("-I%s -I%s", luajit_inc, ffmpeg_inc)
	self.ctx.shell:execute(string.format("%s %s %s -o %s %s %s", cc, inc, flags, out, src, libs))
end

function Builder:buildMinacalc()
	local t = self.target
	local cc = self:getCompiler()
	-- Minacalc needs C++ compiler
	local cxx = toCxx(cc)
	if not compilerAvailable(self.ctx.shell, cxx) then
		error("Missing C++ compiler for target '" .. t .. "': " .. cxx .. ". Run ./rizu/build/make.lua setup")
	end
	local src_dir = "build/deps/minacalc"

	if not self.ctx.fs:getInfo(src_dir) then return end

	local out_map = {
		windows = self:getModuleOutputs().minacalc,
		macos = self:getModuleOutputs().minacalc,
		linux = self:getModuleOutputs().minacalc,
	}
	local out = out_map[t] or out_map.linux
	local flags = "-DSTANDALONE_CALC -std=c++20 -shared -fPIC"
	if t == "macos" then
		flags = flags .. " -undefined dynamic_lookup"
	end

	print("Building Minacalc for " .. t .. "...")
	-- Use bash -c to ensure glob expansion works
	local cmd = string.format("bash -c '%s %s %s/MinaCalc/*.cpp %s/API.cpp -o %s -lm'", cxx, flags, src_dir, src_dir, out)
	self.ctx.shell:execute(cmd)
end

function Builder:buildLuamidi()
	local t = self.target
	local cc = self:getCompiler()
	local cxx = toCxx(cc)
	if not compilerAvailable(self.ctx.shell, cxx) then
		error("Missing C++ compiler for target '" .. t .. "': " .. cxx .. ". Run ./rizu/build/make.lua setup")
	end
	local src_dir = "build/deps/luamidi"

	if not self.ctx.fs:getInfo(src_dir) then return end
	if not self.ctx.fs:getInfo(src_dir .. "/rtmidi/RtMidi.h") or not self.ctx.fs:getInfo(src_dir .. "/rtmidi/RtMidi.cpp") then
		error("luamidi RtMidi sources are missing. Run ./rizu/build/make.lua deps " .. t)
	end

	local out_map = {
		windows = self:getModuleOutputs().luamidi,
		macos = self:getModuleOutputs().luamidi,
		linux = self:getModuleOutputs().luamidi,
	}
	local out = out_map[t] or out_map.linux

	print("Building luamidi for " .. t .. "...")
	local luajit_inc = "tree/include/luajit-2.1"
	local rtmidi_inc = src_dir .. "/rtmidi"
	local src = string.format("%s/src/luamidi.cpp %s/rtmidi/RtMidi.cpp", src_dir, src_dir)
	local flags = "-shared -fPIC -std=c++17 -DluaL_reg=luaL_Reg"
	local libs = ""

	if t == "windows" then
		flags = flags .. " -DWIN32 -D__WINDOWS_MM__"
		libs = "-lwinmm -Ltree/lib -l:libluajit-5.1.dll.a"
	elseif t == "macos" then
		flags = flags .. " -D__MACOSX_CORE__ -undefined dynamic_lookup"
		libs = "-framework CoreMIDI -framework CoreFoundation -framework CoreAudio -framework CoreServices"
	else
		flags = flags .. " -D__LINUX_ALSA__"
		libs = "-lasound -lpthread"
	end

	local cmd = string.format("%s %s -I%s -I%s %s -o %s %s", cxx, flags, luajit_inc, rtmidi_inc, src, out, libs)
	self.ctx.shell:execute(cmd)
end

function Builder:run()
	self:build7z()
	self:buildVideo()
	self:buildMinacalc()
	self:buildLuamidi()
end

function Builder:syncMissingToBin()
	local t = self.target
	local out = self:getModuleOutputs()
	local bin_dir = self:getBinDir()
	local pairs_map = BuildConfig.getModuleRecords(t, out, bin_dir)

	for _, item in ipairs(pairs_map) do
		if self.ctx.fs:getInfo(item.artifact) and not self.ctx.fs:getInfo(item.bin) then
			self.ctx.shell:execute(string.format("cp -f %q %q", item.artifact, item.bin))
		end
	end
end

return Builder
