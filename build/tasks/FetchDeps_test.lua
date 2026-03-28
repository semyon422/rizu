local FetchDeps = require("build.tasks.FetchDeps")
local Loader = require("build.deps_dsl.spec.Loader")
local Context = require("build.deps_dsl.engine.Context")
local deps = require("build.deps")

local test = {}

local function makeCtx()
	local state = {info = {}, dirs = {}, exec = {}, downloads = {}}
	local fs = {}
	function fs:getInfo(path) return state.info[path] end
	function fs:createDirectory(path)
		state.dirs[path] = true
		state.info[path] = state.info[path] or {type = "directory"}
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
		state.info[dest] = {type = "file", size = 100}
	end

	return {fs = fs, shell = shell, downloader = downloader}, state
end

local function markRequired(state, spec)
	local fakeCtx = {
		fs = {createDirectory = function() end, getInfo = function() return nil end},
		shell = {popen = function() return "/repo\n" end},
	}
	local env = Context.new(fakeCtx, spec.target, {initialize_dirs = false})
	for _, p in ipairs(spec.required_paths) do
		state.info[p:gsub("${([%w_]+)}", function(k)
			return ({
				target = env.target,
				root_abs = env.root_abs,
				bin_dir = env.bin_dir,
				downloads_dir = env.downloads_dir,
				deps_dir = env.deps_dir,
				bin_linux = env.bin_dirs.linux,
				bin_windows = env.bin_dirs.windows,
				bin_macos = env.bin_dirs.macos,
			})[k] or ""
		end)] = {type = "file", size = 1}
	end
end

function test.up_to_date_parity_linux_windows(t)
	local ctx, state = makeCtx()
	local taskLinux = FetchDeps("linux")
	local taskWindows = FetchDeps("windows")

	t:eq(taskLinux:upToDate(ctx), false)
	t:eq(taskWindows:upToDate(ctx), false)

	local specLinux = Loader.load("linux", deps)
	markRequired(state, specLinux)
	t:eq(taskLinux:upToDate(ctx), true)

	local specWindows = Loader.load("windows", deps)
	markRequired(state, specWindows)
	t:eq(taskWindows:upToDate(ctx), true)
end

function test.status_contains_major_rows(t)
	local ctx, state = makeCtx()
	local specLinux = Loader.load("linux", deps)
	markRequired(state, specLinux)

	local rows = FetchDeps("linux"):getStatus(ctx)
	local names = {}
	for _, row in ipairs(rows) do names[row.name] = true end
	t:assert(names["FFmpeg (linux)"])
	t:assert(names["7z SDK"])
	t:assert(names["MINACALC (git)"])
	t:assert(names["LUAMIDI (git)"])
end

return test
