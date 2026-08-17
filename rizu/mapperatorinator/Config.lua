local Config = require("rizu.config.Config")

---@class rizu.mapperatorinator.Config.Keys
local keys = {
	repository_path = "mapperatorinator.repository_path",
	python_path = "mapperatorinator.python_path",
	gamemode = "mapperatorinator.gamemode",
	difficulty = "mapperatorinator.difficulty",
	keycount = "mapperatorinator.keycount",
	year = "mapperatorinator.year",
}

local MapperatorinatorConfig = {keys = keys}

---@param filesystem fs.IFilesystem
---@param home string?
---@return rizu.config.Config
function MapperatorinatorConfig.create(filesystem, home)
	home = home or os.getenv("HOME") or ""
	local config = Config(filesystem, "userdata/mapperatorinator.json")
	config:setDefaultString(keys.repository_path, home .. "/code/Mapperatorinator")
	config:setDefaultString(keys.python_path, home .. "/code/Mapperatorinator/.venv/bin/python")
	config:setDefaultChoice(keys.gamemode, "osu!mania", {"osu!mania", "osu!standard", "osu!taiko", "osu!catch"})
	config:setDefaultNumber(keys.difficulty, 5, 0.1, 15, 0.1)
	config:setDefaultNumber(keys.keycount, 4, 1, 18, 1)
	config:setDefaultNumber(keys.year, 2024, 2007, 2024, 1)
	return config
end

return MapperatorinatorConfig
