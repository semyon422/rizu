local FFmpegSpec = require("rizu.build.deps.spec.common.FFmpegSpec")
local BassDepsSpec = require("rizu.build.deps.spec.common.BassDepsSpec")
local DiscordRpcSpec = require("rizu.build.deps.spec.common.DiscordRpcSpec")
local GitDepsSpec = require("rizu.build.deps.spec.common.GitDepsSpec")
local SevenZipSpec = require("rizu.build.deps.spec.common.SevenZipSpec")
local LoveArtifactsSpec = require("rizu.build.deps.spec.common.LoveArtifactsSpec")

---@class rizu.build.deps.spec.CommonSpec
local CommonSpec = {}

---@param target rizu.build.Target
---@param deps rizu.build.deps.Manifest
---@return rizu.build.deps.Spec
function CommonSpec.buildShared(target, deps)
	local spec = {
		target = target,
		steps = {},
		outputs = {},
	}

	FFmpegSpec.add(target, deps, spec)
	BassDepsSpec.add(target, deps, spec)
	DiscordRpcSpec.add(target, deps, spec)
	GitDepsSpec.add(deps, spec)
	SevenZipSpec.add(deps, spec)
	LoveArtifactsSpec.add(deps, spec)

	return spec
end

return CommonSpec
