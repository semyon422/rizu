local Ctx = require("build.deps_dsl.engine.Context")

local Guards = {}

local function existsAll(fs, paths)
	for _, p in ipairs(paths or {}) do
		if not fs:getInfo(p) then
			return false
		end
	end
	return true
end

local function resolveList(env, list)
	local out = {}
	for _, p in ipairs(list or {}) do
		table.insert(out, Ctx.interpolate(env, p))
	end
	return out
end

function Guards.resolveRequiredPaths(env, spec)
	return resolveList(env, spec.required_paths)
end

function Guards.isUpToDate(env, spec)
	local req = Guards.resolveRequiredPaths(env, spec)
	return existsAll(env.ctx.fs, req)
end

return Guards
