#!/usr/bin/env luajit

require("pkg_config")

local Context = require("rizu.build.Context")
local TaskRunner = require("rizu.build.TaskRunner")
local LinuxFilesystem = require("fs.LinuxFilesystem")
local Shell = require("rizu.build.Shell")
local Downloader = require("rizu.build.Downloader")

local SetupHostTask = require("rizu.build.tasks.SetupHostTask")
local SetupLuaJITTask = require("rizu.build.tasks.SetupLuaJITTask")
local SetupMacOSToolchainTask = require("rizu.build.tasks.SetupMacOSToolchainTask")
local BuildTargetTask = require("rizu.build.tasks.BuildTargetTask")
local PrefetchDepsTask = require("rizu.build.tasks.PrefetchDepsTask")
local AssembleRepoTask = require("rizu.build.tasks.AssembleRepoTask")
local ZipRepoTask = require("rizu.build.tasks.ZipRepoTask")
local PackageMacOSTask = require("rizu.build.tasks.PackageMacOSTask")

---@type (string?)[]
local args = {...}
local command = args[1]
local target_arg = args[2]
local scope_arg = args[2]

local ctx = Context(
	LinuxFilesystem(),
	Shell(),
	Downloader(),
	target_arg or "linux"
)

local runner = TaskRunner(ctx)

runner:register(SetupHostTask())
runner:register(SetupLuaJITTask("linux"))
runner:register(SetupLuaJITTask("windows"))
runner:register(SetupMacOSToolchainTask())
runner:register(BuildTargetTask("linux"))
runner:register(BuildTargetTask("windows"))
runner:register(BuildTargetTask("macos"))
runner:register(PrefetchDepsTask("linux"))
runner:register(PrefetchDepsTask("windows"))
runner:register(PrefetchDepsTask("macos"))
runner:register(AssembleRepoTask())
runner:register(ZipRepoTask())
runner:register(PackageMacOSTask())

local function getTargetOrDefault()
	return target_arg or "linux"
end

local function getScopeOrDefault()
	return scope_arg or "all"
end

local commands = {
	setup = {
		help = "Install host dependencies (apt)",
		run = function()
			runner:run("setup_host")
		end,
	},
	luajit = {
		help = "Build/install luajit locally: luajit <linux|windows>",
		run = function()
			runner:run("setup_luajit_" .. getTargetOrDefault())
		end,
	},
	setup_macos_toolchain = {
		help = "Setup osxcross for macOS compilation",
		run = function()
			runner:run("setup_macos_toolchain")
		end,
	},
	build_target = {
		help = "Run full build pipeline for target: build_target <linux|windows|macos>",
		run = function()
			runner:run("build_target_" .. getTargetOrDefault())
		end,
	},
	prefetch = {
		help = "Download/clone deps only: prefetch <linux|windows|macos|all>",
		run = function()
			local target = target_arg or "all"
			if target == "all" then
				runner:run("prefetch_deps_linux")
				runner:run("prefetch_deps_windows")
				runner:run("prefetch_deps_macos")
			else
				runner:run("prefetch_deps_" .. target)
			end
		end,
	},
	repo = {
		help = "Assemble update repository files and index",
		run = function()
			runner:run("assemble_repo")
		end,
	},
	package = {
		help = "Build distributable archives (zip + macos app zip)",
		run = function()
			runner:run("zip_repo")
			runner:run("package_macos")
		end,
	},
	status = {
		help = "Show build state: status <target|all>",
		run = function()
			print("=== Rizu Build Status ===")
			local target = getTargetOrDefault()
			local targets = target == "all" and {"linux", "windows", "macos"} or {target}
			for _, t in ipairs(targets) do
				local task = runner.tasks["build_target_" .. t]
				if task and task.getStatus then
					for _, res in ipairs(task:getStatus(ctx)) do
						print(string.format("  %-30s [%s]", res.name, res.value))
					end
				end
			end
			local global_tasks = {"assemble_repo", "zip_repo", "package_macos"}
			for _, task_name in ipairs(global_tasks) do
				local task = runner.tasks[task_name]
				if task and task.getStatus then
					for _, res in ipairs(task:getStatus(ctx)) do
						print(string.format("  %-30s [%s]", res.name, res.value))
					end
				end
			end
			print("=========================")
			os.exit(0)
		end,
	},
	clean = {
		help = "Clean outputs: clean <all|deps|downloads|artifacts|bin|repo>",
		run = function()
			local scope = getScopeOrDefault()
			if scope == "all" or scope == "deps" then
				ctx.fs:remove("build/deps")
			end
			if scope == "all" or scope == "downloads" then
				ctx.fs:remove("build/downloads")
			end
			if scope == "all" or scope == "artifacts" then
				ctx.fs:remove("build/artifacts")
			end
			if scope == "all" or scope == "bin" then
				ctx.fs:remove("bin/linux64")
				ctx.fs:remove("bin/win64")
				ctx.fs:remove("bin/mac64")
			end
			if scope == "all" or scope == "repo" then
				ctx.fs:remove("build/repo")
			end
			print("Cleaned: " .. scope)
			os.exit(0)
		end,
	},
}

local function help()
	print("Rizu Build System")
	print("Usage: ./rizu/build/make.lua <command> [arg]")
	print("")
	print("Commands:")
	local order = {"setup", "luajit", "setup_macos_toolchain", "build_target", "prefetch", "repo", "package", "status", "clean", "help"}
	for _, name in ipairs(order) do
		if name == "help" then
			print("  help                   Show this help")
		else
			print(string.format("  %-22s %s", name, commands[name].help))
		end
	end
end

if command == "help" or command == nil then
	help()
	os.exit(0)
end

local entry = commands[command]
if not entry then
	help()
	os.exit(1)
end

entry.run()
