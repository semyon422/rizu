local UpdateLoveTask = require("rizu.build.tasks.UpdateLoveTask")
local TaskRegistry = require("rizu.build.TaskRegistry")
local TaskRunner = require("rizu.build.TaskRunner")
local BuildConfig = require("rizu.build.BuildConfig")
local FakeFilesystem = require("fs.FakeFilesystem")

local test = {}

local function makeCtx()
	local fs = FakeFilesystem()
	fs:setWorkingDirectory("/repo")
	fs:setTime(1)
	local state = {fs = fs, commands = {}, downloads = {}}
	local function write(path, data)
		fs:createDirectory(assert(path:match("(.+)/[^/]+$")))
		assert(fs:write(path, data))
	end
	for _, name in ipairs({"love.exe", "lovec.exe", "love.dll", "lua51.dll", "SDL3.dll", "OpenAL32.dll"}) do
		write("bin/win64/" .. name, "old runtime")
	end
	write("bin/linux64/love-linux-X64.AppImage", "old runtime")
	for _, name in ipairs({"love-linux-X64.AppImage.zip", "love-windows-x64.zip", "love-macos.zip", "bass-linux.zip"}) do
		write("build/downloads/" .. name, "cached archive")
	end
	---@type rizu.build.IShell
	local shell = {}
	function shell:execute(command)
		table.insert(state.commands, command)
		return true
	end
	function shell:popen() return "" end
	---@type rizu.build.IDownloader
	local downloader = {}
	function downloader:download(url, dest)
		table.insert(state.downloads, {url = url, dest = dest})
		write(dest, "new archive")
		return true
	end
	return {fs = fs, shell = shell, downloader = downloader}, state
end

---@param t testing.T
function test.refreshes_cached_love_without_build_dependencies(t)
	local archives = {
		linux = "love-linux-X64.AppImage.zip",
		windows = "love-windows-x64.zip",
		macos = "love-macos.zip",
	}
	for _, target in ipairs(BuildConfig.TARGETS) do
		local ctx, state = makeCtx()
		local task = UpdateLoveTask(target)
		t:tdeq(task.deps, {})
		task:run(ctx)
		t:eq(#state.downloads, 1)
		t:eq(state.downloads[1].dest, "build/downloads/" .. archives[target])
		t:eq(state.downloads[1].url, "https://nightly.link/love2d/love/workflows/main/main/" .. archives[target])
		t:eq(ctx.fs:read("build/downloads/bass-linux.zip"), "cached archive")
		local commands = table.concat(state.commands, "\n")
		if target == "linux" then
			t:assert(commands:find("unzip -o", 1, true), "existing runtime must be reinstalled")
			t:assert(commands:find('chmod +x "bin/linux64/love-linux-X64.AppImage"', 1, true))
		elseif target == "windows" then
			t:assert(commands:find("unzip -o", 1, true), "existing runtime must be reinstalled")
			t:assert(commands:find("cp -rf", 1, true))
		else
			t:eq(commands, "", "macOS only refreshes the packaging input")
		end
		task:run(ctx)
		t:eq(#state.downloads, 2, "every explicit refresh must download again")
	end
end

---@param t testing.T
function test.failed_download_keeps_runtime_and_cache(t)
	local ctx, state = makeCtx()
	ctx.downloader.download = function() return false end
	local ok = pcall(UpdateLoveTask("linux").run, UpdateLoveTask("linux"), ctx)
	t:eq(ok, false)
	t:eq(#state.commands, 0, "do not install after a failed download")
	t:eq(ctx.fs:read("bin/linux64/love-linux-X64.AppImage"), "old runtime")
	t:eq(ctx.fs:read("build/downloads/love-linux-X64.AppImage.zip"), "cached archive")
end

---@param t testing.T
function test.registers_standalone_tasks(t)
	local ctx = makeCtx()
	local runner = TaskRunner(ctx)
	TaskRegistry.registerTasks(runner)
	for _, target in ipairs(BuildConfig.TARGETS) do
		local task = runner.tasks["update_love_" .. target]
		t:assert(task)
		t:tdeq(task.deps, {})
	end
	t:eq(pcall(function() UpdateLoveTask("invalid" --[[@as rizu.build.Target]]) end), false)
end

return test
