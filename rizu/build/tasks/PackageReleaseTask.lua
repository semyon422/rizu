local ITask = require("rizu.build.ITask")
local ReleasePackager = require("rizu.build.package.ReleasePackager")

---@class rizu.build.tasks.PackageReleaseTask: rizu.build.ITask
---@operator call: rizu.build.tasks.PackageReleaseTask
---@field name string
---@field deps string[]
local PackageReleaseTask = ITask + {}

function PackageReleaseTask:new()
	self.name = "package_release"
	self.deps = {"zip_repo", "package_macos"}
end

---@param ctx rizu.build.Context
function PackageReleaseTask:run(ctx)
	ReleasePackager(ctx):build()
end

---@param ctx rizu.build.Context
---@return rizu.build.StatusRow[]
function PackageReleaseTask:getStatus(ctx)
	local commit = ctx.shell:popen("git rev-parse HEAD")
	commit = commit and commit:match("^%s*([0-9a-fA-F]+)")
	local path = commit and #commit == 40 and "build/release/" .. commit:lower() .. "/release.json"
	return {
		{name = "Release Artifact", value = path and ctx.fs:getInfo(path) and "OK" or "MISSING"},
	}
end

return PackageReleaseTask
