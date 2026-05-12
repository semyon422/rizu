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

---@class rizu.build.TaskRegistry
local TaskRegistry = {}

---@type rizu.build.Target[]
TaskRegistry.LUAJIT_TARGETS = {"linux", "windows"}

---@return rizu.build.Context
function TaskRegistry.createContext()
	local fs = LinuxFilesystem()
	local shell = Shell()
	local downloader = Downloader(shell)
	return Context(fs, shell, downloader)
end

---@param runner rizu.build.TaskRunner
function TaskRegistry.registerTasks(runner)
	runner:register(SetupHostTask())
	for _, target in ipairs(TaskRegistry.LUAJIT_TARGETS) do
		runner:register(SetupLuaJITTask(target))
	end
	runner:register(SetupMacOSToolchainTask())
	for _, target in ipairs(BuildConfig.TARGETS) do
		runner:register(BuildTargetTask(target))
		runner:register(PrefetchDepsTask(target))
	end
	runner:register(AssembleRepoTask())
	runner:register(ZipRepoTask())
	runner:register(PackageMacOSTask())
end

---@return rizu.build.Context
---@return rizu.build.TaskRunner
function TaskRegistry.create()
	local ctx = TaskRegistry.createContext()
	local runner = TaskRunner(ctx)
	TaskRegistry.registerTasks(runner)
	return ctx, runner
end

return TaskRegistry
