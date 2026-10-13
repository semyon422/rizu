local dirs = {}

local dirs_list = {
	"userdata",
	"userdata/pkg",
	"userdata/dlc",
	"userdata/dlc/skins_rizu",
	"userdata/dlc/skins_osu",
	"userdata/charts",
	"userdata/charts/downloads",
	"userdata/charts/mapperatorinator",
	"userdata/export",
	"userdata/hitsounds",
	"userdata/replays",
	"userdata/score_systems",
	"userdata/screenshots",
}

function dirs.create()
	for _, path in ipairs(dirs_list) do
		if not love.filesystem.getInfo(path) then
			love.filesystem.createDirectory(path)
		end
	end
end

return dirs
