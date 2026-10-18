local json = require("json")
local posix = require("scripts.luals.posix")

--- Finds lua-language-server, and installs it into the project from
--- https://github.com/LuaLS/lua-language-server, either a release build or built from source.
local Installer = {}

Installer.repository = "LuaLS/lua-language-server"

--- The version `install` picks by default, so everyone checks with the same LuaLS.
Installer.default_version = "3.19.1"

---@param root string
---@return string
function Installer.install_dir(root)
	return root .. "/build/lua-language-server"
end

---@param dir string
---@return string
local function executable_in(dir)
	return dir .. "/bin/lua-language-server"
end

--- Looks in order at `explicit`, `$LUA_LANGUAGE_SERVER`, the project install, then `PATH`.
---@param root string
---@param explicit string?
---@return string? executable
---@return string? error
function Installer.find(root, explicit)
	if explicit then
		if not posix.is_executable(explicit) then
			return nil, "not an executable: " .. explicit
		end
		return posix.realpath(explicit) or explicit
	end
	---@type string[]
	local candidates = {}
	table.insert(candidates, os.getenv("LUA_LANGUAGE_SERVER"))
	table.insert(candidates, executable_in(Installer.install_dir(root)))
	for dir in (os.getenv("PATH") or ""):gmatch("[^:]+") do
		table.insert(candidates, dir .. "/lua-language-server")
	end
	for _, candidate in ipairs(candidates) do
		if posix.is_executable(candidate) then
			return posix.realpath(candidate) or candidate
		end
	end
	return nil, "lua-language-server not found; run `luajit scripts/luals.lua install`, "
		.. "or set LUA_LANGUAGE_SERVER to its executable"
end

---@param file string
---@return string?
local function read_file(file)
	local f = io.open(file, "rb")
	if not f then
		return nil
	end
	local content = f:read("*a")
	f:close()
	return content
end

---@param argv string[]
local function run(argv)
	local code, err = posix.run(argv)
	if code ~= 0 then
		error(err or ("`%s` exited with status %d"):format(table.concat(argv, " "), code), 0)
	end
end

---@return string
local function latest_version()
	local body = assert(posix.capture({
		"curl", "-fsSL", "https://api.github.com/repos/" .. Installer.repository .. "/releases/latest",
	}))
	local release = json.decode(body)
	return assert(release.tag_name, "no tag_name in the latest release")
end

---@param version string
---@return string
local function release_asset(version)
	local os_name = ({Linux = "linux", OSX = "darwin"})[jit.os]
	local arch = ({x64 = "x64", arm64 = "arm64"})[jit.arch]
	if not os_name or not arch then
		error(("no LuaLS release for %s %s; use --source"):format(jit.os, jit.arch), 0)
	end
	return ("lua-language-server-%s-%s-%s.tar.gz"):format(version, os_name, arch)
end

---@param version string
---@param work string
---@param target string
local function download_release(version, work, target)
	local asset = release_asset(version)
	local url = ("https://github.com/%s/releases/download/%s/%s"):format(Installer.repository, version, asset)
	print("Downloading " .. url)
	run({"curl", "-fsSL", "--retry", "3", "-o", work .. "/" .. asset, url})
	run({"mkdir", "-p", target})
	run({"tar", "-xzf", work .. "/" .. asset, "-C", target})
end

---@param name string
---@return boolean
local function on_path(name)
	for dir in (os.getenv("PATH") or ""):gmatch("[^:]+") do
		if posix.is_executable(dir .. "/" .. name) then
			return true
		end
	end
	return false
end

---@param version string
---@param target string
local function build_source(version, target)
	-- make.sh builds luamake first, which needs a C++17 compiler and ninja.
	for _, tool in ipairs({"git", "ninja"}) do
		if not on_path(tool) then
			error(("building LuaLS from source needs %s on PATH"):format(tool), 0)
		end
	end
	if not on_path("c++") and not on_path("g++") and not on_path("clang++") then
		error("building LuaLS from source needs a C++17 compiler on PATH", 0)
	end
	print(("Cloning %s %s"):format(Installer.repository, version))
	run({
		"git", "clone", "--depth", "1", "--branch", version, "--recurse-submodules", "--shallow-submodules",
		"https://github.com/" .. Installer.repository .. ".git", target,
	})
	print("Building " .. target)
	run({"sh", "-c", 'cd "$1" && ./make.sh', "sh", target})
end

---@class scripts.luals.Installer.Options
---@field version string? a release tag, or "latest"
---@field source boolean? build from source instead of downloading a release
---@field force boolean? reinstall even when this version is installed

---@param root string
---@param options scripts.luals.Installer.Options
---@return string executable
function Installer.install(root, options)
	local version = options.version or Installer.default_version
	if version == "latest" then
		version = latest_version()
	end
	local kind = options.source and "source" or "release"
	local stamp = ("%s %s\n"):format(version, kind)

	local dir = Installer.install_dir(root)
	if not options.force and read_file(dir .. "/.rizu-install") == stamp and posix.is_executable(executable_in(dir)) then
		print(("LuaLS %s (%s) is already installed in %s"):format(version, kind, dir))
		return executable_in(dir)
	end

	local work = dir .. ".download"
	local target = work .. "/lua-language-server"
	run({"rm", "-rf", work})
	run({"mkdir", "-p", work})
	local ok, err = pcall(function()
		if options.source then
			build_source(version, target)
		else
			download_release(version, work, target)
		end
		if not posix.is_executable(executable_in(target)) then
			error("the install has no bin/lua-language-server: " .. target, 0)
		end
		run({executable_in(target), "--version"})
	end)
	if not ok then
		posix.run({"rm", "-rf", work})
		error(err, 0)
	end

	run({"rm", "-rf", dir})
	assert(os.rename(target, dir))
	run({"rm", "-rf", work})
	local f = assert(io.open(dir .. "/.rizu-install", "wb"))
	f:write(stamp)
	f:close()
	print(("Installed LuaLS %s (%s) in %s"):format(version, kind, dir))
	return executable_in(dir)
end

return Installer
