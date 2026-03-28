local Pipeline = require("build.tasks.PipelineTask")

local test = {}

local function makeCtx()
	local state = {info = {}, dirs = {}, exec = {}, downloads = {}}
	local fs = {}
	function fs:getInfo(path) return state.info[path] end
	function fs:createDirectory(path)
		state.dirs[path] = true
		state.info[path] = state.info[path] or {type = "directory", modtime = 1}
	end
	function fs:remove(path) state.info[path] = nil end

	local shell = {}
	function shell:execute(cmd)
		table.insert(state.exec, cmd)
		return true
	end
	function shell:popen(cmd)
		if cmd == "pwd" then return "/repo\n" end
		return ""
	end

	local downloader = {}
	function downloader:download(url, dest)
		table.insert(state.downloads, {url = url, dest = dest})
		state.info[dest] = {type = "file", size = 100, modtime = 1}
	end

	return {fs = fs, shell = shell, downloader = downloader}, state
end

function test.pipeline_status_and_uptodate(t)
	local ctx, state = makeCtx()
	local p = Pipeline("linux")
	t:eq(p:upToDate(ctx), false)

	state.info["build/deps/ffmpeg-linux"] = {type = "directory", modtime = 1}
	state.info["build/deps/7zsdk"] = {type = "directory", modtime = 1}
	state.info["build/deps/minacalc"] = {type = "directory", modtime = 1}
	state.info["build/deps/luamidi"] = {type = "directory", modtime = 1}
	state.info["build/deps/luamidi/rtmidi/RtMidi.h"] = {type = "file", modtime = 1}
	state.info["build/artifacts/linux/lib7z.so"] = {type = "file", modtime = 2}
	state.info["build/artifacts/linux/video.so"] = {type = "file", modtime = 2}
	state.info["build/artifacts/linux/libminacalc.so"] = {type = "file", modtime = 2}
	state.info["build/artifacts/linux/luamidi.so"] = {type = "file", modtime = 2}
	state.info["bin/linux64/lib7z.so"] = {type = "file", modtime = 2}
	state.info["bin/linux64/video.so"] = {type = "file", modtime = 2}
	state.info["bin/linux64/libminacalc.so"] = {type = "file", modtime = 2}
	state.info["bin/linux64/luamidi.so"] = {type = "file", modtime = 2}
	state.info["aqua/video.c"] = {type = "file", modtime = 1}
	state.info["aqua/7z.c"] = {type = "file", modtime = 1}

	local rows = p:getStatus(ctx)
	t:assert(#rows > 0)
	t:assert(rows[#rows].name:find("Pipeline"))
end

return test
