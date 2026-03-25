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
		if t == "windows" or t == "win64" then
			return "x86_64-w64-mingw32-gcc"
		elseif t == "macos" then
			return "x86_64-apple-darwin19-clang"
		end
	end
	return "gcc"
end

function Builder:getFFmpegPaths()
	local t = self.ctx.target:lower()
	local suffix = t:match("win") and "win" or "linux"
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
	local out, flags
	
	if t == "windows" or t == "win64" then
		out = "bin/win64/7z.dll"
		flags = "-shared -fPIC"
	elseif t == "macos" then
		out = "bin/macos/lib7z.dylib"
		flags = "-shared -fPIC"
	else
		out = "bin/linux64/lib7z.so"
		flags = "-D_GNU_SOURCE -shared -fPIC"
	end
	
	self.ctx.shell:execute(string.format("%s %s %s -o %s %s", cc, inc, flags, out, src))
end

function Builder:buildVideo()
	local t = self.ctx.target:lower()
	local cc = self:getCompiler()
	local ffmpeg_inc, ffmpeg_lib_dir = self:getFFmpegPaths()
	local luajit_inc = "tree/include/luajit-2.1"
	local src = "aqua/video.c"
	local out, flags, libs
	
	local inc = string.format("-I%s -I%s", luajit_inc, ffmpeg_inc)
	
	if t == "windows" or t == "win64" then
		out = "bin/win64/video.dll"
		libs = string.format("-Ltree/lib -L%s -lavformat -lavcodec -lswresample -lswscale -lavutil -lm -l:libluajit-5.1.dll.a", ffmpeg_lib_dir)
		flags = "-shared -fPIC"
	elseif t == "macos" then
		out = "bin/macos/video.so"
		libs = "-lavformat -lavcodec -lswresample -lswscale -lavutil -lm"
		flags = "-shared -fPIC -undefined dynamic_lookup"
	else
		out = "bin/linux64/video.so"
		libs = string.format("-L%s -lavformat -lavcodec -lswresample -lswscale -lavutil -lm", ffmpeg_lib_dir)
		flags = "-shared -fPIC -Wl,-rpath,'$ORIGIN'"
	end
	
	self.ctx.shell:execute(string.format("%s %s %s -o %s %s %s", cc, inc, flags, out, src, libs))
end

function Builder:run()
	self.ctx.fs:createDirectory("bin/linux64")
	self.ctx.fs:createDirectory("bin/win64")
	self.ctx.fs:createDirectory("bin/macos")
	
	self:build7z()
	self:buildVideo()
end

return Builder
