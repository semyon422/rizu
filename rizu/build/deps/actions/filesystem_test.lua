local filesystem = require("rizu.build.deps.actions.filesystem")
local BuildEnv = require("rizu.build.deps.engine.BuildEnv")
local FakeFilesystem = require("fs.FakeFilesystem")

local test = {}

---@return rizu.build.deps.Env
local function makeEnv()
	local fs = FakeFilesystem()
	fs:setWorkingDirectory("/repo")
	return BuildEnv.new({fs = fs}, "linux")
end

---@param t testing.T
function test.replace_text_replaces_plain_text(t)
	local env = makeEnv()
	env.ctx.fs:write("file.c", "aa one aa one aa")

	local result = filesystem.replace_text(env, {
		type = "replace_text",
		path = "file.c",
		replacements = {
			{old_text = "one", new_text = "two", count = 1},
			{old_text = "aa", new_text = "bb"},
		},
	})

	t:eq(result.ok, true)
	t:eq(env.ctx.fs:read("file.c"), "bb two bb one bb")
end

---@param t testing.T
function test.replace_text_matches_crlf_multiline_text(t)
	local env = makeEnv()
	env.ctx.fs:write("file.c", "a\r\nb\r\nc")

	local result = filesystem.replace_text(env, {
		type = "replace_text",
		path = "file.c",
		replacements = {
			{old_text = "a\nb", new_text = "x\ny"},
		},
	})

	t:eq(result.ok, true)
	t:eq(env.ctx.fs:read("file.c"), "x\r\ny\r\nc")
end

---@param t testing.T
function test.replace_text_errors_when_text_is_missing(t)
	local env = makeEnv()
	env.ctx.fs:write("file.c", "abc")

	t:has_error(function()
		filesystem.replace_text(env, {
			type = "replace_text",
			path = "file.c",
			replacements = {
				{old_text = "missing", new_text = "x"},
			},
		})
	end)
end

return test
