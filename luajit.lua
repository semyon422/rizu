#!/usr/bin/env luajit

local pkg = require("aqua.pkg")

pkg.addc()
pkg.addc("3rd-deps/lib")
pkg.addc("bin/lib")
pkg.addc("tree/lib/lua/5.1")
pkg.add()
pkg.add("3rd-deps/lua")
pkg.add("aqua")
pkg.add("ncdk")
pkg.add("chartbase")
pkg.add("libchart")
pkg.add("tree/share/lua/5.1")

local or_root = os.getenv("OR_ROOT")
if or_root then
	pkg.add(or_root .. "/lualib")
end

pkg.export_lua()

--- Parse -e flag and script path from arg.
--- Returns (loader, remaining_arg_index).
--- @return fun() loader
--- @return integer next_arg
local function parse_args()
	if arg[1] == "-e" then
		local code = arg[2]
		if not code then
			error("Usage: luajit.lua -e <code> [args...]", 0)
		end
		local f, err = load(code, "=(command line)")
		if not f then
			error(string.format("Cannot load code: %s", err), 0)
		end
		return f, 3
	end

	local script_path = arg[1]
	if script_path == "-" then
		local code = io.read("*a")
		local f, err = load(code, "=(stdin)")
		if not f then
			error(string.format("Cannot load stdin: %s", err), 0)
		end
		return f, 2
	end
	if not script_path then
		print("Usage: luajit.lua <script.lua> [args...]\n       luajit.lua - [args...]\n       luajit.lua -e <code> [args...]")
		os.exit(1)
	end

	local f, err = loadfile(script_path)
	if not f then
		error(string.format("Cannot load %s: %s", script_path, err), 0)
	end
	return f, 2
end

local f, next_arg = parse_args()

-- Trim arg so the script receives only its own arguments
for i = 1, next_arg - 1 do
	table.remove(arg, 1)
end

f()
