#!/usr/bin/env luajit

require("pkg_config")

local Context = require("rizu.build.Context")
local TaskRunner = require("rizu.build.TaskRunner")
local BuildConfig = require("rizu.build.BuildConfig")
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
	Downloader()
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

local function getScopeOrDefault()
	return scope_arg or "all"
end

---@type {[string]: true}
local target_set = {}
for _, target in ipairs(BuildConfig.TARGETS) do
	target_set[target] = true
end

---@param message string
local function exitWithError(message)
	io.stderr:write(message .. "\n")
	os.exit(1)
end

---@param target string?
---@param command_name string
---@return rizu.build.Target
local function getTargetArg(target, command_name)
	local t = target or "linux"
	if not target_set[t] then
		exitWithError(string.format("Unsupported target for %s: %s", command_name, tostring(t)))
	end
	return t
end

---@param target string?
---@return "linux"|"windows"
local function getLuaJITTargetArg(target)
	local t = target or "linux"
	if t ~= "linux" and t ~= "windows" then
		exitWithError("Unsupported target for luajit: " .. tostring(t))
	end
	return t
end

---@param target string?
---@param default string
---@return string
local function getTargetOrAllArg(target, default)
	local t = target or default
	if t ~= "all" and not target_set[t] then
		exitWithError("Unsupported target: " .. tostring(t))
	end
	return t
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
			runner:run("setup_luajit_" .. getLuaJITTargetArg(target_arg))
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
			runner:run("build_target_" .. getTargetArg(target_arg, "build_target"))
		end,
	},
	prefetch = {
		help = "Download/clone deps only: prefetch <linux|windows|macos|all>",
		run = function()
			local target = getTargetOrAllArg(target_arg, "all")
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
			local target = getTargetOrAllArg(target_arg, "linux")
			print("=== Rizu Build Status ===")
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
