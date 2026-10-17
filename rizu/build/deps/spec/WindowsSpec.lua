local BuildConfig = require("rizu.build.BuildConfig")
local Common = require("rizu.build.deps.spec.CommonSpec")
local FFTWSourceSpec = require("rizu.build.deps.spec.source.FFTWSourceSpec")
local IconvSourceSpec = require("rizu.build.deps.spec.source.IconvSourceSpec")
local LuaSecSourceSpec = require("rizu.build.deps.spec.source.LuaSecSourceSpec")
local OpenSSLSourceSpec = require("rizu.build.deps.spec.source.OpenSSLSourceSpec")
local PrefixSpec = require("rizu.build.deps.spec.source.PrefixSpec")
local SQLiteSourceSpec = require("rizu.build.deps.spec.source.SQLiteSourceSpec")
local ZlibSourceSpec = require("rizu.build.deps.spec.source.ZlibSourceSpec")
local ModuleDirsSpec = require("rizu.build.deps.spec.module.ModuleDirsSpec")
local SevenZipModuleSpec = require("rizu.build.deps.spec.module.SevenZipModuleSpec")
local VideoModuleSpec = require("rizu.build.deps.spec.module.VideoModuleSpec")
local MinacalcModuleSpec = require("rizu.build.deps.spec.module.MinacalcModuleSpec")
local LuamidiModuleSpec = require("rizu.build.deps.spec.module.LuamidiModuleSpec")
local NeedleModuleSpec = require("rizu.build.deps.spec.module.NeedleModuleSpec")

---@class rizu.build.deps.spec.WindowsSpec
local Windows = {}

---@return rizu.build.deps.Spec
function Windows.build()
	local target = "windows"
	local spec = Common.buildShared(target)
	local prefix = "${deps_dir}/" .. BuildConfig.getLocalPrefixDir("windows")
	local prefix_abs = "${root_abs}/" .. BuildConfig.ROOT_DIRS.deps .. "/" .. BuildConfig.getLocalPrefixDir("windows")

	PrefixSpec.add(target, spec, prefix)
	ZlibSourceSpec.add(target, spec, prefix, prefix_abs)
	IconvSourceSpec.add(target, spec, prefix, prefix_abs)
	OpenSSLSourceSpec.add(target, spec, prefix, prefix_abs)
	LuaSecSourceSpec.add(target, spec, prefix, prefix_abs)
	FFTWSourceSpec.add(target, spec, prefix, prefix_abs)
	SQLiteSourceSpec.add(target, spec, prefix, prefix_abs)

	ModuleDirsSpec.add(target, spec)
	SevenZipModuleSpec.add(target, spec)
	VideoModuleSpec.add(target, spec)
	MinacalcModuleSpec.add(target, spec)
	LuamidiModuleSpec.add(target, spec)
	NeedleModuleSpec.add(target, spec)

	return spec
end

return Windows
