#!/usr/bin/env luajit
-- Rizu Unified Task Runner (Modular Architecture)

require("pkg_config")

local Context = require("build.Context")
local TaskRunner = require("build.TaskRunner")
local LinuxFilesystem = require("fs.LinuxFilesystem")
local Shell = require("build.Shell")
local Downloader = require("build.Downloader")

-- Task Modules
local SetupHost = require("build.tasks.SetupHost")
local SetupLuaJIT = require("build.tasks.SetupLuaJIT")
local FetchDeps = require("build.tasks.FetchDeps")
local BuildModules = require("build.tasks.BuildModules")
local Package = require("build.tasks.Package")
local BuildRepo = require("build.tasks.BuildRepo")
local SetupCrossMacOS = require("build.tasks.SetupCrossMacOS")

local args = {...}
local command = args[1]
local target = args[2] or "linux" -- default target

-- 1. Initialize Context
local ctx = Context(
	LinuxFilesystem(),
	Shell(),
	Downloader(),
	target,
	"." -- Root
)

-- 2. Initialize Runner
local runner = TaskRunner(ctx)

-- 3. Register Tasks
runner:register(SetupHost())
runner:register(SetupLuaJIT("linux"))
runner:register(SetupLuaJIT("windows"))
runner:register(SetupCrossMacOS())
runner:register(FetchDeps("linux"))
runner:register(FetchDeps("windows"))
runner:register(FetchDeps("macos"))
runner:register(BuildModules("linux"))
runner:register(BuildModules("windows"))
runner:register(BuildModules("macos"))
runner:register(Package())
runner:register(BuildRepo())

-- Composite Tasks (Aliases)
runner:register({ name = "all", deps = {"build_" .. target}, run = function() end })

-- 4. Execute
local tasks_map = {
	setup = "setup_host",
	luajit = "setup_luajit_" .. target,
	macos_toolchain = "setup_cross_macos",
	deps = "deps_" .. target,
	build = "build_" .. target,
	package = "package",
	repo = "repo",
	all = "all"
}

local function help()
	print([[
Rizu Build System (Modular)
Usage: ./build/make.lua <command> [target]

Commands:
  setup             Install host dependencies (apt)
  luajit [target]   Build/Install luajit locally (target: linux, windows)
  macos_toolchain   Setup osxcross for macOS compilation
  deps [target]     Fetch binary dependencies (ffmpeg, 7z)
  build [target]    Compile C modules (video, 7z)
  package           Bundle game into zip/app
  repo              Build update repository
  all [target]      Full cycle (deps + build)
  status            Show current build state
  clean             Remove build artifacts
  help              Show this help
]])
end

if command == "status" then
	print("=== Rizu Build Status ===")
	
	local task_order = {
		"setup_host",
		"setup_luajit_linux",
		"setup_luajit_windows",
		"setup_cross_macos",
		"deps_linux",
		"deps_windows",
		"deps_macos",
		"build_linux",
		"build_windows",
		"build_macos",
		"package",
		"repo"
	}

	for _, name in ipairs(task_order) do
		local task = runner.tasks[name]
		if task and task.getStatus then
			local results = task:getStatus(ctx)
			for _, res in ipairs(results) do
				print(string.format("  %-30s [%s]", res.name, res.value))
			end
		end
	end
	
	print("=========================")
	os.exit(0)
end

if command == "clean" then
	ctx.fs:remove("build/deps")
	ctx.fs:remove("bin/linux64")
	ctx.fs:remove("bin/win64")
	ctx.fs:remove("bin/mac64")
	ctx.fs:remove("build/repo")
	print("Cleaned.")
	os.exit(0)
end

local task_name = tasks_map[command]
if not task_name then
	help()
	os.exit(1)
end

runner:run(task_name)
