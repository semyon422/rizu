local NativeModuleBuilder = require("rizu.build.NativeModuleBuilder")
local FakeFilesystem = require("fs.FakeFilesystem")

local test = {}

local function makeCtx()
	local state = {
		fs = FakeFilesystem(),
	}
	state.fs:setWorkingDirectory("/repo")

	local shell = {}
	function shell:execute() return true end
	function shell:popen() return "" end

	local ctx = {
		fs = state.fs,
		shell = shell,
		downloader = {},
		target = "linux",
	}

	return ctx, state
end

function test.macos_compiler_uses_hardcoded_osxcross_clang(t)
	local ctx, state = makeCtx()
	state.fs:createDirectory("build/deps/osxcross/target/bin")
	state.fs:write("build/deps/osxcross/target/bin/x86_64-apple-darwin22.2-clang", "x")

	local cc = NativeModuleBuilder(ctx, "macos"):getCompiler()
	t:assert(cc:find("PATH=/repo/build/deps/osxcross/target/bin:$PATH", 1, true))
	t:assert(cc:find("x86_64-apple-darwin22.2-clang", 1, true))
end

function test.macos_compiler_falls_back_when_osxcross_missing(t)
	local ctx = makeCtx()
	local cc = NativeModuleBuilder(ctx, "macos"):getCompiler()
	t:eq(cc, "x86_64-apple-darwin22.2-clang")
end

return test
