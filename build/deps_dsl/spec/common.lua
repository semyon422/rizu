local FFmpeg = require("build.deps_dsl.spec.common.FFmpeg")
local BassDeps = require("build.deps_dsl.spec.common.BassDeps")
local DiscordRpc = require("build.deps_dsl.spec.common.DiscordRpc")
local GitDeps = require("build.deps_dsl.spec.common.GitDeps")
local SevenZip = require("build.deps_dsl.spec.common.SevenZip")
local LoveArtifacts = require("build.deps_dsl.spec.common.LoveArtifacts")

local Common = {}

function Common.buildShared(target, deps)
	local spec = {
		target = target,
		steps = {},
		outputs = {},
	}

	FFmpeg.add(target, deps, spec)
	BassDeps.add(target, deps, spec)
	DiscordRpc.add(target, deps, spec)
	GitDeps.add(deps, spec)
	SevenZip.add(deps, spec)
	LoveArtifacts.add(deps, spec)

	return spec
end

return Common
