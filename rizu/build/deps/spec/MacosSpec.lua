local Common = require("rizu.build.deps.spec.CommonSpec")
local FFTWSourceSpec = require("rizu.build.deps.spec.source.FFTWSourceSpec")
local FFmpegSourceSpec = require("rizu.build.deps.spec.source.FFmpegSourceSpec")
local IconvSourceSpec = require("rizu.build.deps.spec.source.IconvSourceSpec")
local LuaSecSourceSpec = require("rizu.build.deps.spec.source.LuaSecSourceSpec")
local MacOSCross = require("rizu.build.deps.spec.source.MacOSCross")
local OpenSSLSourceSpec = require("rizu.build.deps.spec.source.OpenSSLSourceSpec")
local PrefixSpec = require("rizu.build.deps.spec.source.PrefixSpec")
local SQLiteSourceSpec = require("rizu.build.deps.spec.source.SQLiteSourceSpec")
local ZlibSourceSpec = require("rizu.build.deps.spec.source.ZlibSourceSpec")

---@class rizu.build.deps.spec.MacosSpec
local Macos = {}

---@param deps rizu.build.deps.Manifest
---@return rizu.build.deps.Spec
function Macos.build(deps)
	local target = "macos"
	local spec = Common.buildShared(target, deps)
	local prefix = "${deps_dir}/local/macos"
	local prefix_abs = "${root_abs}/build/deps/local/macos"
	local tc_bin = MacOSCross.TOOLCHAIN_BIN

	PrefixSpec.add(target, spec, prefix)
	FFmpegSourceSpec.add(target, spec, deps, prefix, prefix_abs, tc_bin)
	ZlibSourceSpec.add(target, spec, deps, prefix, prefix_abs, tc_bin)
	IconvSourceSpec.add(target, spec, deps, prefix, prefix_abs, tc_bin)
	OpenSSLSourceSpec.add(target, spec, deps, prefix, prefix_abs, tc_bin)
	LuaSecSourceSpec.add(target, spec, deps, prefix, prefix_abs, tc_bin)
	FFTWSourceSpec.add(target, spec, deps, prefix, prefix_abs, tc_bin)
	SQLiteSourceSpec.add(target, spec, deps, prefix, prefix_abs, tc_bin)

	return spec
end

return Macos
