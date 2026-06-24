local FFmpegSpec = require("rizu.build.deps.spec.common.FFmpegSpec")
local BassDepsSpec = require("rizu.build.deps.spec.common.BassDepsSpec")
local BassFfmpegSpec = require("rizu.build.deps.spec.common.BassFfmpegSpec")
local DiscordRpcSpec = require("rizu.build.deps.spec.common.DiscordRpcSpec")
local GitDepsSpec = require("rizu.build.deps.spec.common.GitDepsSpec")
local SevenZipSpec = require("rizu.build.deps.spec.common.SevenZipSpec")
local LoveArtifactsSpec = require("rizu.build.deps.spec.common.LoveArtifactsSpec")

---@class rizu.build.deps.spec.CommonSpec
local CommonSpec = {}

---@param target rizu.build.Target
---@return rizu.build.deps.Spec
function CommonSpec.buildShared(target)
	local spec = {
		target = target,
		steps = {},
	}

	FFmpegSpec.add(target, spec)
	BassDepsSpec.add(target, spec)
	BassFfmpegSpec.add(target, spec)
	DiscordRpcSpec.add(target, spec)
	GitDepsSpec.add(spec)
	SevenZipSpec.add(spec)
	LoveArtifactsSpec.add(spec)

	return spec
end

return CommonSpec
