local Ctx = require("build.deps_dsl.engine.Context")

local StatusFormatter = {}

local function interp(env, value)
	return Ctx.interpolate(env, value)
end

local function status_dl_ex(env, row)
	local dl = env.ctx.fs:getInfo(interp(env, row.download)) and "OK" or "MISSING"
	local ex = env.ctx.fs:getInfo(interp(env, row.extract)) and "OK" or "MISSING"
	if dl == "MISSING" and ex == "OK" then
		dl = "CACHED"
	end
	return string.format("DL: [%s] EX: [%s]", dl, ex)
end

local function status_exists(env, row)
	return env.ctx.fs:getInfo(interp(env, row.path)) and "OK" or "MISSING"
end

local function status_exists_all(env, row)
	for _, p in ipairs(row.paths or {}) do
		if not env.ctx.fs:getInfo(interp(env, p)) then
			return "MISSING"
		end
	end
	return "OK"
end

local formatters = {
	dl_ex = status_dl_ex,
	exists = status_exists,
	exists_all = status_exists_all,
}

function StatusFormatter.render(env, spec)
	local rows = {}
	for _, row in ipairs(spec.status_rows or {}) do
		local fmt = formatters[row.format]
		if not fmt then
			error("Unknown status format: " .. tostring(row.format))
		end
		table.insert(rows, {name = row.name, value = fmt(env, row)})
	end
	return rows
end

return StatusFormatter
