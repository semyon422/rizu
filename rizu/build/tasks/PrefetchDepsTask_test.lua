local PrefetchDepsTask = require("rizu.build.tasks.PrefetchDepsTask")
local FakeFilesystem = require("fs.FakeFilesystem")

local test = {}

local function makeCtx()
	local state = {fs = FakeFilesystem(), exec = {} --[=[@as string[]]=], downloads = {}}
	state.fs:setWorkingDirectory("/repo")

	---@type rizu.build.IShell
	local shell = {}
	function shell:execute(cmd)
		table.insert(state.exec, cmd)
		local clone_dest = cmd:match("^git clone .+ ([^%s]+)$")
		if clone_dest then
			state.fs:setTime(1)
			state.fs:createDirectory(clone_dest)
		end
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

---@param t testing.T
function test.prefetch_only_downloads_and_git(t)
	local ctx, state = makeCtx()
	local task = PrefetchDepsTask("linux")
	task:run(ctx)

	t:assert(#state.downloads > 0, "expected at least one download")
	for _, cmd in ipairs(state.exec) do
		local is_git = cmd:match("^git clone ") or cmd:match("^git %-C .+ submodule update %-%-init %-%-recursive$")
		t:assert(is_git, "only git commands are allowed during prefetch: " .. tostring(cmd))
	end
end

---@param t testing.T
function test.prefetch_macos_includes_osxcross_clone(t)
	local ctx, state = makeCtx()
	local task = PrefetchDepsTask("macos")
	task:run(ctx)

	local found = false
	for _, cmd in ipairs(state.exec) do
		if cmd:find("git clone https://github.com/tpoechtrager/osxcross", 1, true) then
			found = true
			break
		end
	end
	t:assert(found, "expected osxcross clone during macos prefetch")
end

return test
