local SkinResourceContext = require("rizu.skin.SkinResourceContext")
local FakeFilesystem = require("fs.FakeFilesystem")

local test = {}

---@param t testing.T
function test.normalized_sorted_files_and_directory_boundaries(t)
	local context = SkinResourceContext(nil, {
		skin_path = "example.skin.lua", directory_path = "skins\\example/",
		files = {"33\\b.png", "330/c.png", "33/./a.png", "33/a.png"},
		roots = {fallback = {directory_path = "resources/fallback", files = {"note.png"}}},
	})
	t:tdeq(context.files, {"33/a.png", "33/b.png", "330/c.png"})
	t:tdeq(context:getFiles("33"), {"33/a.png", "33/b.png"})
	t:tdeq(context:getFiles("", "fallback"), {"note.png"})
	t:eq(context:resolvePath("33/../note.png"), "skins/example/note.png")
	t:eq(context:resolvePath("note.png", "fallback"), "resources/fallback/note.png")
	t:assert(not pcall(context.resolvePath, context, "../outside.png"))
	t:assert(not pcall(context.resolvePath, context, "/outside.png"))
	t:assert(not pcall(context.resolvePath, context, "C:\\outside.png"))
	t:assert(not pcall(context.resolvePath, context, "33/../../outside.png"))
	t:assert(not pcall(context.resolvePath, context, "\\\\server\\outside.png"))
	t:eq(SkinResourceContext.normalizePath("33//./nested/../note.png/"), "33/note.png")
	t:eq(SkinResourceContext.normalizePath("33/.."), "")
end

---@param t testing.T
function test.read_failure_includes_skin_and_asset(t)
	local context = SkinResourceContext(FakeFilesystem(), {
		skin_path = "custom.skin.lua", directory_path = "skin", files = {},
	})
	local ok, err = pcall(context.loadImageData, context, "missing.png")
	t:assert(not ok)
	t:assert(tostring(err):find("custom.skin.lua", 1, true))
	t:assert(tostring(err):find("skin/missing.png", 1, true))
end

---@param t testing.T
function test.worker_request_is_plain_and_independent(t)
	local context = SkinResourceContext(FakeFilesystem(), {
		skin_path = "example.skin.lua", directory_path = "skins/example/./",
		files = {"a.png"},
		roots = {fallback = {directory_path = "fallback", files = {"b.png"}}},
	})
	local assets = {{name = "a", path = "a.png"}}
	local request = context:createRequest(assets)
	t:eq(getmetatable(request), nil)
	t:eq(rawget(request, "fs"), nil)
	t:eq(request.directory_path, "skins/example")
	assets[1].path = "changed.png"
	context.files[1] = "changed.png"
	context.roots.fallback.files[1] = "changed.png"
	t:eq(request.assets[1].path, "a.png")
	t:tdeq(request.files, {"a.png"})
	t:tdeq(request.roots.fallback.files, {"b.png"})
end

---@param t testing.T
function test.normalizes_and_joins_explicit_roots(t)
	local context = SkinResourceContext(nil, {
		skin_path = "example.skin.lua", directory_path = "skins//old/../example/",
		roots = {
			unix = {directory_path = "/resources//old/../fallback/", files = {}},
			windows = {directory_path = "C:\\resources\\old\\..\\fallback\\", files = {}},
			root = {directory_path = "/", files = {}},
			empty = {directory_path = "", files = {}},
		},
	})
	t:eq(context.directory_path, "skins/example")
	t:eq(context:resolvePath("./note.png"), "skins/example/note.png")
	t:eq(context:resolvePath("note.png", "unix"), "/resources/fallback/note.png")
	t:eq(context:resolvePath("note.png", "windows"), "C:/resources/fallback/note.png")
	t:eq(context:resolvePath("note.png", "root"), "/note.png")
	t:eq(context:resolvePath("note.png", "empty"), "note.png")
end

return test
