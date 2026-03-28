local Env = require("build.tasks.fetchdeps.env")

local test = {}

local function makeCtx()
	local state = {
		info = {},
		dirs = {},
		exec = {},
		downloads = {},
	}
	local fs = {}
	function fs:getInfo(path)
		return state.info[path]
	end
	function fs:createDirectory(path)
		state.dirs[path] = true
		if not state.info[path] then
			state.info[path] = {type = "directory"}
		end
	end
	function fs:getDirectoryItems(path)
		local items = state.info[path .. ":items"]
		if items then
			return items
		end
		return {}
	end

	local shell = {}
	function shell:execute(cmd)
		table.insert(state.exec, cmd)
		return true
	end
	function shell:popen(cmd)
		if cmd == "pwd" then
			return "/repo\n"
		end
		return ""
	end

	local downloader = {}
	function downloader:download(url, dest)
		table.insert(state.downloads, {url = url, dest = dest})
		state.info[dest] = {type = "file", size = 10}
	end

	return {
		fs = fs,
		shell = shell,
		downloader = downloader,
	}, state
end

function test.ensure_source_dep_extracts_by_archive_type(t)
	local ctx, state = makeCtx()
	local env = Env.new(ctx, "linux", {})

	Env.ensure_source_dep(env, {
		archive = "zlib.tar.gz",
		dir = "zlib_linux",
		url = "https://example.invalid/zlib.tar.gz",
	})
	t:eq(#state.downloads, 1)
	t:eq(state.downloads[1].dest, "build/downloads/zlib.tar.gz")
	t:assert(state.exec[#state.exec]:find("tar %-xzf"))

	state.exec = {}
	Env.ensure_source_dep(env, {
		archive = "sqlite.tar.xz",
		dir = "sqlite_linux",
		url = "https://example.invalid/sqlite.tar.xz",
	})
	t:assert(state.exec[#state.exec]:find("tar %-xf"))
end

function test.ensure_source_dep_rejects_unknown_format(t)
	local ctx = makeCtx()
	local env = Env.new(ctx, "linux", {})

	local ok, err = pcall(function()
		Env.ensure_source_dep(env, {
			archive = "unknown.zip",
			dir = "whatever",
			url = "https://example.invalid/unknown.zip",
		})
	end)
	t:eq(ok, false)
	t:assert(tostring(err):find("Unsupported source archive format"))
end

function test.resolve_macos_toolchain_detects_direct_and_fallback(t)
	local ctx, state = makeCtx()
	local env = Env.new(ctx, "macos", {})

	state.info["build/deps/osxcross/target/bin/x86_64-apple-darwin22.2-clang"] = {type = "file"}
	local tc = Env.resolve_macos_toolchain(env)
	t:assert(tc)
	t:eq(tc.host, "x86_64-apple-darwin22.2")

	state.info["build/deps/osxcross/target/bin/x86_64-apple-darwin22.2-clang"] = nil
	state.info["build/deps/osxcross/target/bin:items"] = {"x86_64-apple-darwin23.1-clang"}
	tc = Env.resolve_macos_toolchain(env)
	t:assert(tc)
	t:eq(tc.host, "x86_64-apple-darwin23.1")
end

return test
