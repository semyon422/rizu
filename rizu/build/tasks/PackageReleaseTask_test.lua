local PackageReleaseTask = require("rizu.build.tasks.PackageReleaseTask")

local test = {}

---@param t testing.T
function test.release_depends_on_all_client_packages(t)
	local task = PackageReleaseTask()
	t:eq(task.name, "package_release")
	t:tdeq(task.deps, {"zip_repo", "package_macos"})
end

return test
