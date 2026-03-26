local class = require("class")

---@class build.Builder
---@field ctx build.Context
local Builder = class()

function Builder:new(ctx)
	self.ctx = ctx
end

function Builder:getCompiler()
	local t = self.ctx.target:lower()
	
	if jit.os == "Linux" then
		local compilers = {
			windows = "x86_64-w64-mingw32-gcc",
			macos   = "x86_64-apple-darwin22.2-clang",
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
	local t = self.ctx.target:lower()
	local suffix_map = {
		windows = "win",
		macos   = "macos", -- potentially
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

function Builder:build7z()
	local t = self.ctx.target:lower()
	local cc = self:getCompiler()
	local inc = "-I" .. self:get7zInc()
	local src = "aqua/7z.c"
	
	local out_map = {
		windows = "bin/win64/7z.dll",
		macos   = "bin/mac64/lib7z.dylib",
		linux   = "bin/linux64/lib7z.so",
	}
	local flag_map = {
		linux = "-D_GNU_SOURCE -shared -fPIC",
	}
	
	local out = out_map[t] or out_map.linux
	local flags = flag_map[t] or "-shared -fPIC"
	
	self.ctx.shell:execute(string.format("%s %s %s -o %s %s", cc, inc, flags, out, src))
end

function Builder:buildVideo()
	local t = self.ctx.target:lower()
	local cc = self:getCompiler()
	local ffmpeg_inc, ffmpeg_lib_dir = self:getFFmpegPaths()
	if not ffmpeg_inc then
		print("FFmpeg headers not found for " .. t .. ", skipping video module build.")
		return
	end
	
	local luajit_inc = "tree/include/luajit-2.1"
	local src = "aqua/video.c"
	
	local out_map = {
		windows = "bin/win64/video.dll",
		macos   = "bin/mac64/video.so",
		linux   = "bin/linux64/video.so",
	}
	local flag_map = {
		macos = "-shared -fPIC -undefined dynamic_lookup",
		linux = "-shared -fPIC -Wl,-rpath,'$ORIGIN'",
	}
	
	local out = out_map[t] or out_map.linux
	local flags = flag_map[t] or "-shared -fPIC"
	
	local libs
	if t == "windows" then
		libs = string.format("-Ltree/lib -L%s -lavformat -lavcodec -lswresample -lswscale -lavutil -lm -l:libluajit-5.1.dll.a", ffmpeg_lib_dir)
	elseif t == "macos" then
		libs = "-lavformat -lavcodec -lswresample -lswscale -lavutil -lm"
	else
		libs = string.format("-L%s -lavformat -lavcodec -lswresample -lswscale -lavutil -lm", ffmpeg_lib_dir)
	end
	
	local inc = string.format("-I%s -I%s", luajit_inc, ffmpeg_inc)
	self.ctx.shell:execute(string.format("%s %s %s -o %s %s %s", cc, inc, flags, out, src, libs))
end

function Builder:buildMinacalc()
	local t = self.ctx.target:lower()
	local cc = self:getCompiler()
	-- Minacalc needs C++ compiler
	local cxx = cc:gsub("gcc", "g++"):gsub("clang", "clang++")
	local src_dir = "build/deps/minacalc"
	
	if not self.ctx.fs:getInfo(src_dir) then return end

	local out_map = {
		windows = "bin/win64/minacalc.dll",
		macos   = "bin/mac64/libminacalc.dylib",
		linux   = "bin/linux64/libminacalc.so",
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
	local t = self.ctx.target:lower()
	local cc = self:getCompiler()
	local src_dir = "build/deps/luamidi"
	
	if not self.ctx.fs:getInfo(src_dir) then return end

	if t == "windows" then
		print("Using precompiled luamidi.dll for Windows...")
		self.ctx.shell:execute(string.format("cp %s/luamidi.dll_64 bin/win64/luamidi.dll", src_dir))
		return
	end

	local out_map = {
		macos   = "bin/mac64/luamidi.dylib",
		linux   = "bin/linux64/luamidi.so",
	}
	local out = out_map[t] or out_map.linux
	local flags = "-shared -fPIC"
	if t == "macos" then
		flags = flags .. " -undefined dynamic_lookup"
	end

	print("Building luamidi for " .. t .. "...")
	local luajit_inc = "tree/include/luajit-2.1"
	local rtmidi_inc = "/usr/include/rtmidi"
	local l_flags = flags .. " -DluaL_reg=luaL_Reg"
	-- Basic compilation, luamidi source is in src/ folder
	local cmd = string.format("%s %s -I%s -I%s %s/src/*.cpp -o %s -lrtmidi", cc:gsub("gcc", "g++"), l_flags, luajit_inc, rtmidi_inc, src_dir, out)
	self.ctx.shell:execute(cmd)
end

function Builder:run()
	self.ctx.fs:createDirectory("bin/linux64")
	self.ctx.fs:createDirectory("bin/win64")
	self.ctx.fs:createDirectory("bin/mac64")
	
	self:build7z()
	self:buildVideo()
	self:buildMinacalc()
	self:buildLuamidi()
end

return Builder
