local Path = require("Path")

--[[
Finds other rhythm games by what their installers write to the Windows registry.

	local read = OtherGames.getRegistryReader()
	if read then
		for _, game in ipairs(OtherGames.find(read)) do
			library:addLocation(game.name, game.songs)
		end
	end
]]

---@class rizu.other_games.Game
---@field name string
---@field path string The game's folder.
---@field songs string Its chart folder.

---Reads the default value of a key, nil when there is none.
---@alias rizu.other_games.RegistryReader fun(root: string, key: string): string?

local OtherGames = {}

---@param path string?
---@return aqua.Path?
local function folder(path)
	if not path or path == "" then return end
	return Path(path):toDirectory()
end

---The folder of the program in a shell command: `"C:\osu!\osu!.exe" "%1"` gives `C:/osu!`.
---@param command string?
---@return aqua.Path?
local function programFolder(command)
	local program = command and command:match('^"([^"]+)"')
	local path = program and Path(program):trimLast()
	if path and not path:isEmpty() then return path end
end

---@param read rizu.other_games.RegistryReader
---@return rizu.other_games.Game[]
function OtherGames.find(read)
	---@type rizu.other_games.Game[]
	local games = {}
	---@param name string
	---@param path aqua.Path?
	local function add(name, path)
		if path then
			games[#games + 1] = {name = name, path = tostring(path:toFile()), songs = tostring(path .. "Songs")}
		end
	end
	add("osu!", programFolder(read("HKEY_CLASSES_ROOT", [[osustable.File.osz\shell\open\command]])))
	add("Etterna", folder(read("HKEY_LOCAL_MACHINE", [[SOFTWARE\WOW6432Node\Etterna Team\Etterna]])))
	add("Quaver", programFolder(read("HKEY_CURRENT_USER", [[SOFTWARE\Classes\quaver\shell\open\command]])))
	return games
end

---The registry of this system, nil when there is none.
---@return rizu.other_games.RegistryReader?
function OtherGames.getRegistryReader()
	if jit.os ~= "Windows" then return end
	local winapi = require("winapi")
	return function(root, key)
		return (winapi.get_reg_value_sz(winapi.hkey[root], key))
	end
end

return OtherGames
