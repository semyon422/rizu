local FakeFilesystem = require("fs.FakeFilesystem")
local UpdateIndexWriter = require("rizu.build.package.UpdateIndexWriter")
local json = require("json")

local test = {}

---@param t testing.T
function test.urls_point_into_published_repo_directory(t)
	local fs = FakeFilesystem()
	fs:createDirectory("build/repo/rizu/bin")
	fs:write("build/repo/rizu/bin/game", "data")
	local writer = UpdateIndexWriter({fs = fs}, {
		game = {repo = "https://repo.example"},
		repo = {name = "rizu"},
	})
	writer:write("build/repo/rizu")

	local files = json.decode(assert(fs:read("build/repo/files.json")))
	t:eq(files[1].url, "https://repo.example/rizu/bin/game")
end

return test
