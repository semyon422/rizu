local BuildEnv = require("rizu.build.deps.engine.BuildEnv")
local Evaluator = require("rizu.build.deps.engine.Evaluator")
local FakeFilesystem = require("fs.FakeFilesystem")
local LuaJITSpec = require("rizu.build.deps.spec.common.LuaJITSpec")

local test = {}

---@param t testing.T
function test.linux_spec_has_clone_and_install_steps(t)
	local spec = LuaJITSpec.load("linux")
	t:eq(#spec.steps, 2)
	t:eq(spec.steps[1].id, "luajit_clone")
	t:eq(spec.steps[2].id, "luajit_linux_install")
end

---@param t testing.T
function test.windows_spec_requires_linux_headers(t)
	local spec = LuaJITSpec.load("windows")
	t:eq(#spec.steps, 1)
	t:eq(spec.steps[1].id, "luajit_windows_install")
	t:assert(spec.steps[1].inputs[1] == "tree/include/luajit-2.1/lua.h")
end

---@param t testing.T
function test.linux_install_step_ok_when_outputs_exist(t)
	local fs = FakeFilesystem()
	fs:setWorkingDirectory("/repo")
	fs:setTime(1)
	fs:createDirectory("build/deps/LuaJIT")
	fs:setTime(2)
	fs:createDirectory("tree/include/luajit-2.1")
	fs:createDirectory("tree/bin")
	fs:write("tree/include/luajit-2.1/lua.h", "x")
	fs:write("tree/bin/luajit", "x")

	local ctx = {fs = fs, shell = {execute = function() return true end, popen = function() return "" end}}
	local env = BuildEnv.new(ctx, "linux", {initialize_dirs = false})
	local spec = LuaJITSpec.load("linux")
	local install = spec.steps[2]
	t:eq(Evaluator.evaluateStep(env, install).state, "OK")
end

return test
