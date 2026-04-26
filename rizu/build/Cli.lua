local BuildConfig = require("rizu.build.BuildConfig")
local TaskRegistry = require("rizu.build.TaskRegistry")

local Cli = {}

---@type {[string]: true}
local target_set = {}
for _, target in ipairs(BuildConfig.TARGETS) do
	target_set[target] = true
end

---@type {[string]: true}
local luajit_target_set = {}
for _, target in ipairs(TaskRegistry.LUAJIT_TARGETS) do
	luajit_target_set[target] = true
end

local target_help = table.concat(BuildConfig.TARGETS, "|")
local luajit_target_help = table.concat(TaskRegistry.LUAJIT_TARGETS, "|")

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
		exitWithError(string.format("Unsupported target for %s: %s (expected %s)", command_name, tostring(t), target_help))
	end
	return t
end

---@param target string?
---@return "linux"|"windows"
local function getLuaJITTargetArg(target)
	local t = target or "linux"
	if not luajit_target_set[t] then
		exitWithError(string.format("Unsupported target for luajit: %s (expected %s)", tostring(t), luajit_target_help))
	end
	return t
end

---@param target string?
---@param default string
---@return string
local function getTargetOrAllArg(target, default)
	local t = target or default
	if t ~= "all" and not target_set[t] then
		exitWithError(string.format("Unsupported target: %s (expected %s or all)", tostring(t), target_help))
	end
	return t
end

---@param ctx rizu.build.Context
---@param path string
local function removePath(ctx, path)
	if not ctx.fs:getInfo(path) then
		return
	end
	if not ctx.fs:remove(path) then
		exitWithError("Failed to clean: " .. path)
	end
end

---@param ctx rizu.build.Context
---@param scope string
local function clean(ctx, scope)
	if scope == "all" or scope == "deps" then
		removePath(ctx, "build/deps")
	end
	if scope == "all" or scope == "downloads" then
		removePath(ctx, "build/downloads")
	end
	if scope == "all" or scope == "artifacts" then
		removePath(ctx, "build/artifacts")
	end
	if scope == "all" or scope == "bin" then
		for _, target in ipairs(BuildConfig.TARGETS) do
			removePath(ctx, BuildConfig.getBinDir(target))
		end
	end
	if scope == "all" or scope == "repo" then
		removePath(ctx, "build/repo")
	end
	print("Cleaned: " .. scope)
end

---@param ctx rizu.build.Context
---@param runner rizu.build.TaskRunner
---@param target_arg string?
local function printStatus(ctx, runner, target_arg)
	local target = getTargetOrAllArg(target_arg, "linux")
	print("=== Rizu Build Status ===")
	local targets = target == "all" and BuildConfig.TARGETS or {target}
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
end

---@param commands table
local function help(commands)
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

---@param ctx rizu.build.Context
---@param runner rizu.build.TaskRunner
---@param target_arg string?
---@param scope_arg string?
---@return table
local function createCommands(ctx, runner, target_arg, scope_arg)
	return {
		setup = {
			help = "Install host dependencies (apt)",
			run = function()
				runner:run("setup_host")
			end,
		},
		luajit = {
			help = "Build/install luajit locally: luajit <" .. luajit_target_help .. ">",
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
			help = "Run full build pipeline for target: build_target <" .. target_help .. ">",
			run = function()
				runner:run("build_target_" .. getTargetArg(target_arg, "build_target"))
			end,
		},
		prefetch = {
			help = "Download/clone deps only: prefetch <" .. target_help .. "|all>",
			run = function()
				local target = getTargetOrAllArg(target_arg, "all")
				if target == "all" then
					for _, t in ipairs(BuildConfig.TARGETS) do
						runner:run("prefetch_deps_" .. t)
					end
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
				printStatus(ctx, runner, target_arg)
				os.exit(0)
			end,
		},
		clean = {
			help = "Clean outputs: clean <all|deps|downloads|artifacts|bin|repo>",
			run = function()
				clean(ctx, scope_arg or "all")
				os.exit(0)
			end,
		},
	}
end

---@param args (string?)[]
function Cli.run(args)
	local command = args[1]
	local target_arg = args[2]
	local scope_arg = args[2]
	local ctx, runner = TaskRegistry.create()
	local commands = createCommands(ctx, runner, target_arg, scope_arg)

	if command == "help" or command == nil then
		help(commands)
		os.exit(0)
	end

	local entry = commands[command]
	if not entry then
		help(commands)
		os.exit(1)
	end

	entry.run()
end

return Cli
