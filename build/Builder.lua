local class = require("class")

---@class build.Builder
---@field ctx build.Context
local Builder = class()

function Builder:new(ctx)
	self.ctx = ctx
end

function Builder:getCompiler()
	local host_os = jit.os
	local t = self.ctx.target:lower()
	
	if host_os == "Linux" then
		local compilers = {
			windows = "x86_64-w64-mingw32-gcc",
			macos   = "x86_64-apple-darwin19-clang",
		}
		return compilers[t] or "gcc"
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
		return "tree/include", "tree/lib"
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

function Builder:run()
	self.ctx.fs:createDirectory("bin/linux64")
	self.ctx.fs:createDirectory("bin/win64")
	self.ctx.fs:createDirectory("bin/mac64")
	
	self:build7z()
	self:buildVideo()
end

return Builder
