local Util = require("rizu.build.deps.actions._util")
local NativeModuleBuilder = require("rizu.build.NativeModuleBuilder")

local M = {}

function M.build_modules(env, _action)
	local builder = NativeModuleBuilder(env.ctx, env.target)
	builder:run()
	return Util.resultOk("builder:run")
end

function M.sync_binaries(env, _action)
	local builder = NativeModuleBuilder(env.ctx, env.target)
	builder:syncMissingToBin()
	return Util.resultOk("builder:syncMissingToBin")
end

function M.noop(_env, _action)
	return Util.resultOk("<noop>")
end

return M
