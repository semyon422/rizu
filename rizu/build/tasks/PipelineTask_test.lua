local Pipeline = require("rizu.build.tasks.PipelineTask")
local FakeFilesystem = require("fs.FakeFilesystem")

local test = {}

local function makeCtx()
	local state = {fs = FakeFilesystem(), exec = {}, downloads = {}}
	state.fs:setWorkingDirectory("/repo")

	local shell = {}
	function shell:execute(cmd)
		table.insert(state.exec, cmd)
		return true
	end
	function shell:popen() return "" end

	local downloader = {}
	function downloader:download(url, dest)
		table.insert(state.downloads, {url = url, dest = dest})
		state.fs:setTime(1)
		local parent = dest:match("(.+)/[^/]+$")
		if parent then
			state.fs:createDirectory(parent)
		end
		state.fs:write(dest, string.rep("x", 100))
	end

	return {fs = state.fs, shell = shell, downloader = downloader}, state
end

function test.pipeline_status_and_uptodate(t)
	local ctx, state = makeCtx()
	local p = Pipeline("linux")
	t:eq(p:upToDate(ctx), false)

	state.fs:setTime(1)
	state.fs:createDirectory("build/deps/ffmpeg-linux")
	state.fs:createDirectory("build/deps/7zsdk")
	state.fs:createDirectory("build/deps/minacalc")
	state.fs:createDirectory("build/deps/luamidi")
	state.fs:createDirectory("build/deps/luamidi/rtmidi")
	state.fs:write("build/deps/luamidi/rtmidi/RtMidi.h", "x")
	state.fs:createDirectory("aqua")
	state.fs:write("aqua/video.c", "x")
	state.fs:write("aqua/7z.c", "x")

	state.fs:setTime(2)
	state.fs:createDirectory("build/artifacts/linux")
	state.fs:write("build/artifacts/linux/lib7z.so", "x")
	state.fs:write("build/artifacts/linux/video.so", "x")
	state.fs:write("build/artifacts/linux/libminacalc.so", "x")
	state.fs:write("build/artifacts/linux/luamidi.so", "x")
	state.fs:createDirectory("bin/linux64")
	state.fs:write("bin/linux64/lib7z.so", "x")
	state.fs:write("bin/linux64/video.so", "x")
	state.fs:write("bin/linux64/libminacalc.so", "x")
	state.fs:write("bin/linux64/luamidi.so", "x")

	local rows = p:getStatus(ctx)
	t:assert(#rows > 0)
	t:assert(rows[#rows].name:find("Pipeline"))
end

return test
