local FFmpegSpec = require("build.deps_dsl.spec.common.FFmpegSpec")
local BassDepsSpec = require("build.deps_dsl.spec.common.BassDepsSpec")
local DiscordRpcSpec = require("build.deps_dsl.spec.common.DiscordRpcSpec")
local GitDepsSpec = require("build.deps_dsl.spec.common.GitDepsSpec")
local SevenZipSpec = require("build.deps_dsl.spec.common.SevenZipSpec")
local LoveArtifactsSpec = require("build.deps_dsl.spec.common.LoveArtifactsSpec")

local CommonSpec = {}

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
