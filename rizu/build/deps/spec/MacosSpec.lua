local BuildConfig = require("rizu.build.BuildConfig")
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
local ModuleDirsSpec = require("rizu.build.deps.spec.module.ModuleDirsSpec")
local SevenZipModuleSpec = require("rizu.build.deps.spec.module.SevenZipModuleSpec")
local VideoModuleSpec = require("rizu.build.deps.spec.module.VideoModuleSpec")
local MinacalcModuleSpec = require("rizu.build.deps.spec.module.MinacalcModuleSpec")
local LuamidiModuleSpec = require("rizu.build.deps.spec.module.LuamidiModuleSpec")

---@class rizu.build.deps.spec.MacosSpec
local Macos = {}

---@return rizu.build.deps.Spec
function Macos.build()
	local target = "macos"
	local spec = Common.buildShared(target)
	local prefix = "${deps_dir}/" .. BuildConfig.getLocalPrefixDir("macos")
	local prefix_abs = "${root_abs}/" .. BuildConfig.ROOT_DIRS.deps .. "/" .. BuildConfig.getLocalPrefixDir("macos")
	local tc_bin = MacOSCross.TOOLCHAIN_BIN

	PrefixSpec.add(target, spec, prefix)
	FFmpegSourceSpec.add(target, spec, prefix, prefix_abs, tc_bin)
	ZlibSourceSpec.add(target, spec, prefix, prefix_abs, tc_bin)
	IconvSourceSpec.add(target, spec, prefix, prefix_abs, tc_bin)
	OpenSSLSourceSpec.add(target, spec, prefix, prefix_abs, tc_bin)
	LuaSecSourceSpec.add(target, spec, prefix, prefix_abs, tc_bin)
	FFTWSourceSpec.add(target, spec, prefix, prefix_abs, tc_bin)
	SQLiteSourceSpec.add(target, spec, prefix, prefix_abs, tc_bin)

	ModuleDirsSpec.add(target, spec)
	SevenZipModuleSpec.add(target, spec)
	VideoModuleSpec.add(target, spec)
	MinacalcModuleSpec.add(target, spec)
	LuamidiModuleSpec.add(target, spec)

	return spec
end

return Macos
