local pkg = require("aqua.pkg")
local table_util = require("table_util")

local test = {}

---@param t testing.T
function test.thread_keeps_the_shared_love_require_path(t)
	local old = {arg = arg, love = love, path = package.path, cpath = package.cpath, loaded = package.loaded.pkg_config}
	local lua_paths, c_paths = table_util.copy(pkg.lua_paths), table_util.copy(pkg.c_paths)

	local set = false
	love = {filesystem = {
		getRequirePath = function() return "pkg_mount/1/?.lua;?.lua" end,
		getCRequirePath = function() return "??" end,
		setRequirePath = function() set = true end,
		setCRequirePath = function() set = true end,
	}}
	arg = nil
	package.loaded.pkg_config = nil
	local ok, err = pcall(require, "pkg_config")
	local imported = table_util.indexof(pkg.lua_paths, "pkg_mount/1")

	arg, love, package.path, package.cpath = old.arg, old.love, old.path, old.cpath
	package.loaded.pkg_config = old.loaded
	pkg.lua_paths, pkg.c_paths = lua_paths, c_paths

	t:assert(ok, err)
	t:assert(not set, "a thread must not reset the require path of every thread")
	t:assert(imported, "a thread takes the package folders from LÖVE")
end

return test
