local Common = require("rizu.build.deps.spec.CommonSpec")
local FFTWSourceSpec = require("rizu.build.deps.spec.source.FFTWSourceSpec")
local IconvSourceSpec = require("rizu.build.deps.spec.source.IconvSourceSpec")
local LuaSecSourceSpec = require("rizu.build.deps.spec.source.LuaSecSourceSpec")
local OpenSSLSourceSpec = require("rizu.build.deps.spec.source.OpenSSLSourceSpec")
local PrefixSpec = require("rizu.build.deps.spec.source.PrefixSpec")
local SQLiteSourceSpec = require("rizu.build.deps.spec.source.SQLiteSourceSpec")
local ZlibSourceSpec = require("rizu.build.deps.spec.source.ZlibSourceSpec")

---@class rizu.build.deps.spec.WindowsSpec
local Windows = {}

---@param deps rizu.build.deps.Manifest
---@return rizu.build.deps.Spec
function Windows.build(deps)
	local target = "windows"
	local spec = Common.buildShared(target, deps)
	local prefix = "${deps_dir}/local/windows"
	local prefix_abs = "${root_abs}/build/deps/local/windows"

	PrefixSpec.add(target, spec, prefix)
	ZlibSourceSpec.add(target, spec, deps, prefix, prefix_abs)
	IconvSourceSpec.add(target, spec, deps, prefix, prefix_abs)
	OpenSSLSourceSpec.add(target, spec, deps, prefix, prefix_abs)
	LuaSecSourceSpec.add(target, spec, deps, prefix, prefix_abs)
	FFTWSourceSpec.add(target, spec, deps, prefix, prefix_abs)
	SQLiteSourceSpec.add(target, spec, deps, prefix, prefix_abs)

	return spec
end

return Windows
