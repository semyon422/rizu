local BuildTargetTask = require("rizu.build.tasks.BuildTargetTask")
local BuildEnv = require("rizu.build.deps.engine.BuildEnv")
local PipelineSpec = require("rizu.build.deps.spec.PipelineSpec")
local deps = require("rizu.build.deps.Manifest")
local FakeFilesystem = require("fs.FakeFilesystem")

local test = {}

local function makeCtx()
	local state = {fs = FakeFilesystem(), exec = {}, downloads = {}}
	state.fs:setWorkingDirectory("/repo")

	---@type rizu.build.IShell
	local shell = {}
	function shell:execute(cmd)
		table.insert(state.exec, cmd)
		return true
	end
	function shell:popen() return "" end

	---@type rizu.build.IDownloader
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

---@param fs fs.FakeFilesystem
---@param path string
---@param time integer
local function writePath(fs, path, time)
	fs:setTime(time)
	local parent = path:match("(.+)/[^/]+$")
	if parent then
		fs:createDirectory(parent)
	end
	fs:write(path, "x")
end

---@param fs fs.FakeFilesystem
---@param path string
---@param time integer
local function createOutput(fs, path, time)
	if path:match("%.[^/]+$") then
		writePath(fs, path, time)
	else
		fs:setTime(time)
		fs:createDirectory(path)
	end
end

---@param t testing.T
function test.build_target_status_and_uptodate(t)
	local ctx, state = makeCtx()
	local task = BuildTargetTask("linux")
	t:eq(task:upToDate(ctx), false)

	local spec = PipelineSpec.load("linux", deps)
	local env = BuildEnv.new(ctx, "linux", {initialize_dirs = false})
	for _, step in ipairs(spec.steps) do
		for _, path in ipairs(step.inputs or {}) do
			createOutput(state.fs, BuildEnv.interpolate(env, path), 1)
		end
	end

	for _, output in ipairs(spec.outputs) do
		createOutput(state.fs, BuildEnv.interpolate(env, output), 2)
	end

	t:eq(task:upToDate(ctx), true)

	local rows = task:getStatus(ctx)
	t:assert(#rows > 0)
	local saw_video = false
	for _, row in ipairs(rows) do
		if row.name == "Video Artifact" and row.value == "OK" then
			saw_video = true
		end
	end
	t:eq(saw_video, true)
	t:assert(rows[#rows].name:find("Build Target"))
end

return test
