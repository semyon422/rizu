local OtherGames = require("rizu.other_games.OtherGames")

local test = {}

---@param values {[string]: string} Default values by `root\key`.
---@return rizu.other_games.RegistryReader
local function registry(values)
	return function(root, key)
		return values[root .. "\\" .. key]
	end
end

---@param t testing.T
function test.finds_games_from_registry(t)
	local games = OtherGames.find(registry({
		[ [[HKEY_CLASSES_ROOT\osustable.File.osz\shell\open\command]] ] = [["C:\Games\osu!\osu!.exe" "%1"]],
		[ [[HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\Etterna Team\Etterna]] ] = [[D:\Etterna\]],
	}))

	t:tdeq(games, {
		{name = "osu!", path = "C:/Games/osu!", songs = "C:/Games/osu!/Songs"},
		{name = "Etterna", path = "D:/Etterna", songs = "D:/Etterna/Songs"},
	})
end

---@param t testing.T
function test.skips_malformed_commands(t)
	local games = OtherGames.find(registry({
		[ [[HKEY_CURRENT_USER\SOFTWARE\Classes\quaver\shell\open\command]] ] = "quaver.exe %1",
	}))

	t:eq(#games, 0)
end

return test
