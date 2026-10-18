#!/usr/bin/env luajit

--[[
Lua Language Server (LuaLS) diagnostics for one project file, for agents and scripts.

	luajit scripts/luals.lua install
	luajit scripts/luals.lua check rizu/select/SelectionState.lua
	luajit scripts/luals.lua start    # keep a warm LuaLS: checks take a fraction of a second
	luajit scripts/luals.lua stop

Commands:
	check FILE   Print diagnostics for a project .lua file (relative to the current directory or
	             the project). Exits 0 for none, 1 when there are some, 2 on errors.
	start        Start the background daemon for the project. `check` uses it when it runs.
	stop         Stop the daemon.
	status       Print the daemon status as JSON.
	install      Install LuaLS into build/lua-language-server from GitHub.

Options:
	--level L          check: minimum severity, Error|Warning|Information|Hint. Default: Warning
	--format F         check: pretty|json. Default: pretty
	--server-mode M    check: auto (use the daemon when it runs), required, or off. Default: auto
	--server PATH      lua-language-server executable. Default: $LUA_LANGUAGE_SERVER, then the
	                   project install, then PATH
	--project DIR      project with the .luarc.json. Default: this repository
	--version V        install: a release tag or "latest". Default: the pinned version
	--source           install: clone and build from source (needs a C++17 compiler and ninja)
	--force            install: reinstall even when the version is installed

Linux and macOS only. Run with the system luajit, not ./luajit: its address space limit is too
small for LuaLS.
]]

local script = assert(debug.getinfo(1, "S").source:match("^@(.+)$"))
local script_root = script:match("^(.*)/scripts/[^/]+$") or "."
package.path = ("%s/?.lua;%s/?/init.lua;%s"):format(script_root, script_root, package.path)

local posix = require("scripts.luals.posix")
-- A client that goes away before its answer, or LuaLS exiting, must not kill the daemon.
posix.ignore_sigpipe()

script = assert(posix.realpath(script))
script_root = assert(posix.realpath(script_root))

---@param message string
---@return any never returns
local function fail(message)
	io.stderr:write("luals: ", message, "\n")
	os.exit(2)
end

---@type {[string]: boolean}
local switches = {source = false, force = false}
---@type string?
local command
---@type string[]
local positional = {}
---@type {[string]: string}
local options = {}
local i = 1
while i <= #arg do
	local name = arg[i]:match("^%-%-(.+)$")
	if name and switches[name] ~= nil then
		switches[name] = true
		i = i + 1
	elseif name then
		options[name] = arg[i + 1] or fail("missing value for --" .. name)
		i = i + 2
	elseif not command then
		command = arg[i]
		i = i + 1
	else
		table.insert(positional, arg[i])
		i = i + 1
	end
end

local project = options.project and posix.realpath(options.project) or script_root
if not project then
	fail("project not found: " .. options.project)
end
if not io.open(project .. "/.luarc.json") then
	fail("project has no .luarc.json: " .. project)
end

---@type string
local file
if command == "check" then
	local value = positional[1] or fail("usage: luajit scripts/luals.lua check FILE")
	file = posix.realpath(value) or posix.realpath(project .. "/" .. value) or fail("file not found: " .. value)
	if file:sub(1, #project + 1) ~= project .. "/" then
		fail("file must be inside the project: " .. file)
	elseif not file:match("%.lua$") then
		fail("expected a .lua file: " .. file)
	end
end

-- The project's LuaLS workspace takes more than 2 GB of address space.
local limit = posix.address_space_limit()
if limit and limit < 4 * 2 ^ 30 and command ~= "install" and command ~= "stop" and command ~= "status" then
	fail(("address space is limited to %d MB, too little for LuaLS; run with `luajit`, not `./luajit`"):format(limit / 2 ^ 20))
end

-- The game's module paths are relative to the repository root.
assert(posix.chdir(script_root))
require("pkg_config")

local json = require("json")
local Installer = require("scripts.luals.Installer")
local Daemon = require("scripts.luals.Daemon")
local LanguageServer = require("scripts.luals.LanguageServer")

---@return string
local function find_server()
	local executable, err = Installer.find(script_root, options.server)
	return executable or fail(err --[[@as string]])
end

---@return string
local function interpreter()
	local lowest = 0
	while arg[lowest - 1] do
		lowest = lowest - 1
	end
	return arg[lowest] or "luajit"
end

---@param diagnostics scripts.luals.Diagnostic[]
---@param level string
local function report(diagnostics, level)
	if options.format == "json" then
		print(json.encode({file = file, diagnostics = json.array(diagnostics)}, {indent = "  "}))
	elseif #diagnostics > 0 then
		for _, item in ipairs(diagnostics) do
			local code = item.code ~= json.null and (" [%s]"):format(item.code) or ""
			print(("%s:%d:%d: %s: %s%s"):format(file, item.line, item.column, item.severity, item.message, code))
		end
		print(("%d diagnostic(s)"):format(#diagnostics))
	else
		print(("%s: no %s-or-higher diagnostics"):format(file, level:lower()))
	end
	os.exit(#diagnostics > 0 and 1 or 0)
end

local function check()
	local level = options.level or "Warning"
	local mode = options["server-mode"] or "auto"
	if not LanguageServer.levels[level] then
		fail("--level must be Error, Warning, Information or Hint")
	elseif mode ~= "auto" and mode ~= "required" and mode ~= "off" then
		fail("--server-mode must be auto, required or off")
	elseif options.format and options.format ~= "pretty" and options.format ~= "json" then
		fail("--format must be pretty or json")
	end

	if mode ~= "off" then
		local response, err = Daemon.request(project, {action = "diagnostics", file = file, level = level}, 120)
		if response then
			if not response.ok then
				fail(response.error or "the LuaLS daemon failed")
			end
			report(response.diagnostics, level)
		elseif mode == "required" then
			fail(("the LuaLS daemon is unavailable; start it with `luajit scripts/luals.lua start` (%s)"):format(err))
		end
	end

	local base = ("%s/rizu-luals-check-%d"):format(os.getenv("TMPDIR") or "/tmp", posix.getpid())
	local server = LanguageServer(find_server(), project, base .. "-log")
	local ok, result = pcall(server.diagnostics, server, file, level)
	server:close()
	posix.run({"rm", "-rf", base .. "-log"})
	if not ok then
		fail(tostring(result))
	end
	report(result, level)
end

local ok, err = pcall(function()
	if command == "check" then
		check()
	elseif command == "start" then
		print(Daemon.start(project, {interpreter(), script, "serve", "--project", project, "--server", find_server()}))
	elseif command == "serve" then
		Daemon.serve(project, find_server())
	elseif command == "stop" then
		local response, request_err = Daemon.request(project, {action = "stop"}, 10)
		if not response then
			io.stderr:write(("No LuaLS daemon running for %s (%s)\n"):format(project, request_err))
			os.exit(1)
		end
		print("Stopping the LuaLS daemon for " .. project)
	elseif command == "status" then
		local response, request_err = Daemon.request(project, {action = "status"}, 3)
		if not response then
			fail(("no LuaLS daemon running for %s (%s)"):format(project, request_err))
		end
		print(json.encode(response, {indent = "  "}))
	elseif command == "install" then
		Installer.install(script_root, {version = options.version, source = switches.source, force = switches.force})
	else
		fail("usage: luajit scripts/luals.lua check|start|stop|status|install [options]; see the header of scripts/luals.lua")
	end
end)
if not ok then
	fail(tostring(err))
end
