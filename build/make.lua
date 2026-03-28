#!/usr/bin/env luajit

require("pkg_config")

local Context = require("build.Context")
local TaskRunner = require("build.TaskRunner")
local LinuxFilesystem = require("fs.LinuxFilesystem")
local Shell = require("build.Shell")
local Downloader = require("build.Downloader")

local SetupHost = require("build.tasks.SetupHostTask")
local SetupLuaJIT = require("build.tasks.SetupLuaJITTask")
local SetupCrossMacOS = require("build.tasks.SetupCrossMacOSTask")
local Pipeline = require("build.tasks.PipelineTask")
local Package = require("build.tasks.PackageTask")
local BuildRepo = require("build.tasks.BuildRepoTask")

local args = {...}
local command = args[1]
local target = args[2] or "linux"
local scope = args[2] or "all"

local ctx = Context(
	LinuxFilesystem(),
	Shell(),
	Downloader(),
	target,
	"."
)

local runner = TaskRunner(ctx)

runner:register(SetupHost())
runner:register(SetupLuaJIT("linux"))
runner:register(SetupLuaJIT("windows"))
runner:register(SetupCrossMacOS())
runner:register(Pipeline("linux"))
runner:register(Pipeline("windows"))
runner:register(Pipeline("macos"))
runner:register(Package())
runner:register(BuildRepo())

local removed_commands = {
	deps = true,
	build = true,
	sync = true,
	all = true,
}

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
			runner:run("setup_luajit_" .. target)
		end,
	},
	macos_toolchain = {
		help = "Setup osxcross for macOS compilation",
		run = function()
			runner:run("setup_cross_macos")
		end,
	},
	pipeline = {
		help = "Run full pipeline for target: pipeline <linux|windows|macos>",
		run = function()
			runner:run("pipeline_" .. target)
		end,
	},
	package = {
		help = "Bundle game packages",
		run = function()
			runner:run("package")
		end,
	},
	repo = {
		help = "Build update repository",
		run = function()
			runner:run("repo")
		end,
	},
	status = {
		help = "Show pipeline state: status <target|all>",
		run = function()
			print("=== Rizu Build Status ===")
			local targets = target == "all" and {"linux", "windows", "macos"} or {target}
			for _, t in ipairs(targets) do
				local task = runner.tasks["pipeline_" .. t]
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
		help = "Clean outputs: clean <all|deps|artifacts|bin|repo>",
		run = function()
			if scope == "all" or scope == "deps" then
				ctx.fs:remove("build/deps")
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
	print("Rizu Build System (Pipeline)")
	print("Usage: ./build/make.lua <command> [arg]")
	print("")
	print("Commands:")
	local order = {"setup", "luajit", "macos_toolchain", "pipeline", "package", "repo", "status", "clean", "help"}
	for _, name in ipairs(order) do
		if name == "help" then
			print("  help              Show this help")
		else
			print(string.format("  %-17s %s", name, commands[name].help))
		end
	end
end

if command == "help" or command == nil then
	help()
	os.exit(0)
end

if removed_commands[command] then
	print("Command removed: " .. command .. ". Use 'pipeline <target>' instead.")
	help()
	os.exit(1)
end

local entry = commands[command]
if not entry then
	help()
	os.exit(1)
end

entry.run()
