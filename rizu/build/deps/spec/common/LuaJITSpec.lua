local SpecNormalizer = require("rizu.build.deps.spec.SpecNormalizer")
local SpecValidator = require("rizu.build.deps.spec.SpecValidator")

---@class rizu.build.deps.spec.common.LuaJITSpec
local LuaJITSpec = {}

local LUAJIT_REPO = "https://github.com/LuaJIT/LuaJIT"
local LUAJIT_DIR = "${deps_dir}/LuaJIT"
local LUAJIT_SRC = LUAJIT_DIR .. "/src"

---@param luajit_target rizu.build.LuaJITTarget
---@return rizu.build.deps.Spec
function LuaJITSpec.load(luajit_target)
	---@type rizu.build.deps.Step[]
	local steps = {}

	if luajit_target == "linux" then
		table.insert(steps, {
			id = "luajit_clone",
			kind = "git",
			status_label = "LuaJIT Source",
			inputs = {},
			outputs = {LUAJIT_DIR},
			actions = {
				{type = "git_clone", url = LUAJIT_REPO, dest = LUAJIT_DIR},
			},
		})
		table.insert(steps, {
			id = "luajit_linux_install",
			kind = "source-build",
			status_label = "LuaJIT (linux)",
			inputs = {LUAJIT_DIR},
			outputs = {
				"tree/include/luajit-2.1/lua.h",
				"tree/bin/luajit",
			},
			actions = {
				{type = "make", dir = LUAJIT_DIR, args = {"-j$(nproc)"}},
				{type = "make", dir = LUAJIT_DIR, args = {"install", "DESTDIR=${root_abs}/tree", "PREFIX="}},
				{type = "move_first_match", pattern = "${root_abs}/tree/bin/luajit-*", dst = "${root_abs}/tree/bin/luajit"},
			},
		})
	elseif luajit_target == "windows" then
		table.insert(steps, {
			id = "luajit_windows_install",
			kind = "source-build",
			status_label = "LuaJIT (windows)",
			inputs = {
				"tree/include/luajit-2.1/lua.h",
				LUAJIT_DIR,
			},
			outputs = {
				"tree/bin/lua51.dll",
				"tree/lib/libluajit-5.1.dll.a",
			},
			actions = {
				{type = "make", dir = LUAJIT_DIR, args = {"clean"}},
				{
					type = "make",
					dir = LUAJIT_DIR,
					args = {"-j$(nproc)"},
					env = {
						HOST_CC = "gcc -m64",
						CROSS = "x86_64-w64-mingw32-",
						TARGET_SYS = "Windows",
					},
				},
				{type = "ensure_dir", path = "tree/lib"},
				{type = "ensure_dir", path = "tree/bin"},
				{type = "copy", src = LUAJIT_SRC .. "/lua51.dll", dst = "tree/bin/lua51.dll"},
				{type = "copy", src = LUAJIT_SRC .. "/lua51.dll", dst = "tree/lib/lua51.dll"},
				{type = "move_first_match", pattern = LUAJIT_SRC .. "/libluajit*.a", dst = "tree/lib/libluajit-5.1.dll.a"},
			},
		})
	else
		error("Unsupported LuaJIT target: " .. tostring(luajit_target))
	end

	---@type rizu.build.deps.Spec
	local spec = {
		target = luajit_target,
		steps = steps,
	}
	spec = SpecNormalizer.normalize(spec)
	SpecValidator.validate(spec)
	return spec
end

return LuaJITSpec
